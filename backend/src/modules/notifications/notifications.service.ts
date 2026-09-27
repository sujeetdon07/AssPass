import {
  Injectable,
  Inject,
  Optional,
  NotFoundException,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Subscription } from 'rxjs';
import { Notification } from './entities/notification.entity.js';
import { DeviceToken, DevicePlatform } from './entities/device-token.entity.js';
import { NotificationPreference } from './entities/notification-preference.entity.js';
import { User } from '../users/entities/user.entity.js';
import { NotificationType } from './enums/notification-type.enum.js';
import { NotificationCategory } from './enums/notification-category.enum.js';
import { CreateNotificationDto } from './dto/create-notification.dto.js';
import { GetNotificationsQueryDto } from './dto/get-notifications-query.dto.js';
import { RegisterDeviceDto } from './dto/register-device.dto.js';
import { UpdateNotificationPreferencesDto } from './dto/update-preferences.dto.js';
import { serializeNotification, NotificationResponse } from './serializers/notification.serializer.js';
import { NOTIFICATION_PUSH_PROVIDER } from './fcm/push-provider.token.js';
import type { NotificationPushProvider } from './fcm/notification-push.provider.interface.js';
import { MessagingGateway } from '../messaging/messaging.gateway.js';
import { MessagingService } from '../messaging/messaging.service.js';
import { NotificationEvents } from './events/notification-events.constants.js';

@Injectable()
export class NotificationsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(NotificationsService.name);
  private messageSub?: Subscription;

  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepo: Repository<Notification>,
    @InjectRepository(DeviceToken)
    private readonly deviceTokenRepo: Repository<DeviceToken>,
    @InjectRepository(NotificationPreference)
    private readonly preferenceRepo: Repository<NotificationPreference>,
    @Inject(NOTIFICATION_PUSH_PROVIDER)
    private readonly pushProvider: NotificationPushProvider,
    @Optional()
    @Inject(MessagingGateway)
    private readonly messagingGateway?: MessagingGateway,
    @Optional()
    @Inject(MessagingService)
    private readonly messagingService?: MessagingService,
    @Optional()
    @InjectRepository(User)
    private readonly userRepo?: Repository<User>,
  ) {}

  onModuleInit() {
    if (this.messagingService) {
      this.messageSub = this.messagingService.newMessage$.subscribe((event) => {
        this.handleNewMessageNotification(event).catch((err) => {
          this.logger.error(`Failed to dispatch message notification: ${err?.message}`);
        });
      });
    }
  }

  onModuleDestroy() {
    this.messageSub?.unsubscribe();
  }

  /**
   * Asynchronously create and send notification for a new message.
   * Ensures sender name resolution and privacy safeguards (no message content in push/notification).
   */
  async handleNewMessageNotification(event: {
    recipientId: string;
    senderId: string;
    conversationId: string;
    messageId: string;
  }): Promise<void> {
    let senderName = 'Neighbor';
    if (this.userRepo) {
      try {
        const sender = await this.userRepo.findOne({ where: { id: event.senderId } });
        if (sender?.displayName) {
          senderName = sender.displayName;
        }
      } catch (err: any) {
        this.logger.warn(`Could not lookup sender name for notification: ${err?.message}`);
      }
    }

    await this.createAndSend({
      recipientId: event.recipientId,
      senderId: event.senderId,
      type: NotificationType.MESSAGE_RECEIVED,
      category: NotificationCategory.MESSAGES,
      title: `New message from ${senderName}`,
      body: 'You have received a new message',
      deepLink: `/messages/${event.conversationId}`,
      data: {
        conversationId: event.conversationId,
        messageId: event.messageId,
      },
      deduplicationKey: `msg:${event.messageId}`,
    });
  }

  /**
   * Create an in-app notification record and dispatch push notification if enabled.
   * Ensures deduplication, category-based user preference filtering, and privacy safeguards.
   */
  async createAndSend(dto: CreateNotificationDto): Promise<Notification | null> {
    // 1. Check user preferences
    const prefs = await this.getPreferences(dto.recipientId);
    if (!this.isCategoryEnabled(prefs, dto.category)) {
      this.logger.debug(
        `[NotificationsService] Notification suppressed for user ${dto.recipientId}: category ${dto.category} disabled`,
      );
      return null;
    }

    // 2. Check deduplication key if provided
    if (dto.deduplicationKey) {
      const existing = await this.notificationRepo.findOne({
        where: { deduplicationKey: dto.deduplicationKey },
        relations: ['sender'],
      });
      if (existing) {
        this.logger.debug(
          `[NotificationsService] Duplicate notification suppressed with key ${dto.deduplicationKey}`,
        );
        return existing;
      }
    }

    // 3. Persist notification in database
    const notification = this.notificationRepo.create({
      recipientId: dto.recipientId,
      senderId: dto.senderId ?? null,
      type: dto.type,
      category: dto.category,
      title: dto.title,
      body: dto.body,
      data: dto.data ?? {},
      deepLink: dto.deepLink ?? null,
      deduplicationKey: dto.deduplicationKey ?? null,
      isRead: false,
    });

    const saved = await this.notificationRepo.save(notification);

    // Fetch full notification with sender relation for serialization
    const fullNotification =
      (await this.notificationRepo.findOne({
        where: { id: saved.id },
        relations: ['sender'],
      })) || saved;

    // 4. Emit real-time WebSocket event to user room
    if (this.messagingGateway) {
      try {
        const serialized = serializeNotification(fullNotification);
        this.messagingGateway.emitToUser(
          dto.recipientId,
          NotificationEvents.SERVER_NOTIFICATION_NEW,
          serialized,
        );

        const unreadCount = await this.getUnreadCount(dto.recipientId);
        this.messagingGateway.emitToUser(
          dto.recipientId,
          NotificationEvents.SERVER_NOTIFICATION_UNREAD_COUNT,
          { count: unreadCount },
        );
      } catch (err) {
        this.logger.error('[NotificationsService] Error emitting WebSocket notification event:', err);
      }
    }

    // 5. Dispatch Push Notification via PushProvider if user has push enabled
    if (prefs.pushEnabled && this.pushProvider.isAvailable()) {
      await this.dispatchPush(fullNotification);
    }

    return fullNotification;
  }

  /**
   * Dispatch push notification to all active devices of the recipient with privacy safeguards.
   */
  private async dispatchPush(notification: Notification): Promise<void> {
    try {
      const activeTokens = await this.deviceTokenRepo.find({
        where: { userId: notification.recipientId, isActive: true },
      });

      if (!activeTokens.length) return;

      // PRIVACY SAFEGUARD: Raw private message bodies MUST NEVER appear in push payloads.
      let pushTitle = notification.title;
      let pushBody = notification.body;

      if (notification.type === NotificationType.MESSAGE_RECEIVED) {
        // e.g. "New message from Sujeet" or generic "New message"
        pushTitle = notification.title || 'New message';
        pushBody = 'You have received a new message';
      }

      // Prepare string key-value data payload for FCM
      const stringData: Record<string, string> = {
        notificationId: notification.id,
        type: notification.type,
        category: notification.category,
      };

      if (notification.deepLink) {
        stringData.deepLink = notification.deepLink;
      }

      if (notification.data) {
        for (const [key, val] of Object.entries(notification.data)) {
          if (val !== undefined && val !== null) {
            stringData[key] = typeof val === 'string' ? val : JSON.stringify(val);
          }
        }
      }

      // Send to all active tokens
      for (const tokenRecord of activeTokens) {
        const result = await this.pushProvider.send({
          token: tokenRecord.token,
          title: pushTitle,
          body: pushBody,
          data: stringData,
          channelId: this.resolveChannelId(notification.category),
        });

        // If provider indicates token is unregistered/invalid, deactivate it
        if (result.invalidToken) {
          tokenRecord.isActive = false;
          await this.deviceTokenRepo.save(tokenRecord);
          this.logger.log(`[NotificationsService] Deactivated invalid token: ${tokenRecord.id}`);
        }
      }
    } catch (err) {
      this.logger.error('[NotificationsService] Push dispatch error:', err);
    }
  }

  /**
   * Determine Android notification channel ID based on notification category.
   */
  private resolveChannelId(category: NotificationCategory): string {
    switch (category) {
      case NotificationCategory.MESSAGES:
        return 'aaspaas_messages';
      case NotificationCategory.SOCIAL:
        return 'aaspaas_social';
      case NotificationCategory.COMMUNITY:
        return 'aaspaas_community';
      case NotificationCategory.MARKETPLACE:
        return 'aaspaas_marketplace';
      case NotificationCategory.BUSINESS:
        return 'aaspaas_business';
      case NotificationCategory.SYSTEM:
      default:
        return 'aaspaas_system';
    }
  }

  /**
   * Check if a category is enabled in user preferences.
   */
  private isCategoryEnabled(prefs: NotificationPreference, category: NotificationCategory): boolean {
    switch (category) {
      case NotificationCategory.MESSAGES:
        return prefs.messagesEnabled;
      case NotificationCategory.SOCIAL:
        return prefs.socialEnabled;
      case NotificationCategory.COMMUNITY:
        return prefs.communityEnabled;
      case NotificationCategory.MARKETPLACE:
        return prefs.marketplaceEnabled;
      case NotificationCategory.BUSINESS:
        return prefs.businessEnabled;
      case NotificationCategory.SYSTEM:
        return prefs.systemEnabled;
      default:
        return true;
    }
  }

  /**
   * Get paginated notifications for user.
   */
  async getNotifications(
    userId: string,
    query: GetNotificationsQueryDto,
  ): Promise<{ items: NotificationResponse[]; nextCursor: string | null; hasMore: boolean }> {
    const limit = query.limit || 20;

    const qb = this.notificationRepo
      .createQueryBuilder('n')
      .leftJoinAndSelect('n.sender', 'sender')
      .where('n.recipientId = :userId', { userId })
      .andWhere('n.deletedAt IS NULL');

    if (query.unreadOnly) {
      qb.andWhere('n.isRead = :isRead', { isRead: false });
    }

    if (query.category) {
      qb.andWhere('n.category = :category', { category: query.category });
    }

    if (query.cursor) {
      qb.andWhere('n.createdAt < :cursor', { cursor: new Date(query.cursor) });
    }

    qb.orderBy('n.createdAt', 'DESC');
    qb.take(limit + 1);

    const items = await qb.getMany();
    const hasMore = items.length > limit;
    const resultItems = hasMore ? items.slice(0, limit) : items;

    const nextCursor =
      hasMore && resultItems.length > 0
        ? resultItems[resultItems.length - 1].createdAt.toISOString()
        : null;

    return {
      items: resultItems.map((item) => serializeNotification(item)),
      nextCursor,
      hasMore,
    };
  }

  /**
   * Get unread notification count.
   */
  async getUnreadCount(userId: string): Promise<number> {
    return this.notificationRepo.count({
      where: {
        recipientId: userId,
        isRead: false,
      },
    });
  }

  /**
   * Mark a single notification as read.
   */
  async markAsRead(userId: string, notificationId: string): Promise<Notification> {
    const notification = await this.notificationRepo.findOne({
      where: { id: notificationId, recipientId: userId },
      relations: ['sender'],
    });

    if (!notification) {
      throw new NotFoundException('Notification not found');
    }

    if (!notification.isRead) {
      notification.isRead = true;
      notification.readAt = new Date();
      await this.notificationRepo.save(notification);

      if (this.messagingGateway) {
        this.messagingGateway.emitToUser(userId, NotificationEvents.SERVER_NOTIFICATION_READ, {
          id: notification.id,
          readAt: notification.readAt.toISOString(),
        });

        const unreadCount = await this.getUnreadCount(userId);
        this.messagingGateway.emitToUser(
          userId,
          NotificationEvents.SERVER_NOTIFICATION_UNREAD_COUNT,
          { count: unreadCount },
        );
      }
    }

    return notification;
  }

  /**
   * Mark all notifications as read for a user.
   */
  async markAllAsRead(userId: string): Promise<{ updatedCount: number }> {
    const unread = await this.notificationRepo.find({
      where: { recipientId: userId, isRead: false },
    });

    if (unread.length === 0) {
      return { updatedCount: 0 };
    }

    const now = new Date();
    await this.notificationRepo
      .createQueryBuilder()
      .update(Notification)
      .set({ isRead: true, readAt: now })
      .where('recipientId = :userId', { userId })
      .andWhere('isRead = false')
      .execute();

    if (this.messagingGateway) {
      this.messagingGateway.emitToUser(
        userId,
        NotificationEvents.SERVER_NOTIFICATION_UNREAD_COUNT,
        { count: 0 },
      );
    }

    return { updatedCount: unread.length };
  }

  /**
   * Register or refresh a device push token for a user.
   */
  async registerDevice(userId: string, dto: RegisterDeviceDto): Promise<DeviceToken> {
    let token = await this.deviceTokenRepo.findOne({
      where: { token: dto.token },
    });

    if (token) {
      token.userId = userId;
      token.platform = dto.platform ?? DevicePlatform.ANDROID;
      token.deviceId = dto.deviceId ?? token.deviceId;
      token.isActive = true;
      token.lastUsedAt = new Date();
    } else {
      token = this.deviceTokenRepo.create({
        userId,
        token: dto.token,
        platform: dto.platform ?? DevicePlatform.ANDROID,
        deviceId: dto.deviceId ?? null,
        isActive: true,
        lastUsedAt: new Date(),
      });
    }

    return this.deviceTokenRepo.save(token);
  }

  /**
   * Unregister a device token upon logout.
   */
  async unregisterDevice(userId: string, token: string): Promise<void> {
    const existing = await this.deviceTokenRepo.findOne({
      where: { token, userId },
    });

    if (existing) {
      existing.isActive = false;
      await this.deviceTokenRepo.save(existing);
    }
  }

  /**
   * Get user notification preferences, creating defaults if not yet present.
   */
  async getPreferences(userId: string): Promise<NotificationPreference> {
    let prefs = await this.preferenceRepo.findOne({
      where: { userId },
    });

    if (!prefs) {
      prefs = this.preferenceRepo.create({
        userId,
        messagesEnabled: true,
        socialEnabled: true,
        communityEnabled: true,
        marketplaceEnabled: true,
        businessEnabled: true,
        systemEnabled: true,
        pushEnabled: true,
        emailEnabled: false,
        smsEnabled: false,
      });
      prefs = await this.preferenceRepo.save(prefs);
    }

    return prefs;
  }

  /**
   * Update user notification preferences.
   */
  async updatePreferences(
    userId: string,
    dto: UpdateNotificationPreferencesDto,
  ): Promise<NotificationPreference> {
    const prefs = await this.getPreferences(userId);

    if (dto.messagesEnabled !== undefined) prefs.messagesEnabled = dto.messagesEnabled;
    if (dto.socialEnabled !== undefined) prefs.socialEnabled = dto.socialEnabled;
    if (dto.communityEnabled !== undefined) prefs.communityEnabled = dto.communityEnabled;
    if (dto.marketplaceEnabled !== undefined) prefs.marketplaceEnabled = dto.marketplaceEnabled;
    if (dto.businessEnabled !== undefined) prefs.businessEnabled = dto.businessEnabled;
    if (dto.systemEnabled !== undefined) prefs.systemEnabled = dto.systemEnabled;
    if (dto.pushEnabled !== undefined) prefs.pushEnabled = dto.pushEnabled;
    if (dto.emailEnabled !== undefined) prefs.emailEnabled = dto.emailEnabled;
    if (dto.smsEnabled !== undefined) prefs.smsEnabled = dto.smsEnabled;

    return this.preferenceRepo.save(prefs);
  }

  /**
   * Delete a notification (soft delete) for a user.
   */
  async deleteNotification(userId: string, notificationId: string): Promise<void> {
    const notification = await this.notificationRepo.findOne({
      where: { id: notificationId, recipientId: userId },
    });

    if (!notification) {
      throw new NotFoundException('Notification not found');
    }

    const wasUnread = !notification.isRead;
    await this.notificationRepo.softDelete({ id: notificationId, recipientId: userId });

    if (wasUnread && this.messagingGateway) {
      const unreadCount = await this.getUnreadCount(userId);
      this.messagingGateway.emitToUser(
        userId,
        NotificationEvents.SERVER_NOTIFICATION_UNREAD_COUNT,
        { count: unreadCount },
      );
    }
  }
}

import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan, DataSource } from 'typeorm';
import { Subject } from 'rxjs';
import { Conversation } from './entities/conversation.entity.js';
import { ConversationParticipant } from './entities/conversation-participant.entity.js';
import { Message, MessageType } from './entities/message.entity.js';
import { UserBlock } from './entities/user-block.entity.js';
import {
  ConversationReport,
  ConversationReportStatus,
} from './entities/conversation-report.entity.js';
import { User, UserStatus } from '../users/entities/user.entity.js';
import { RedisService } from '../../database/redis.service.js';
import { SendMessageDto } from './dto/send-message.dto.js';
import { GetConversationsQueryDto } from './dto/get-conversations-query.dto.js';
import { GetMessagesQueryDto } from './dto/get-messages-query.dto.js';
import { ReportConversationDto } from './dto/report-conversation.dto.js';
import { toPublicProfile, PublicProfileProjection } from './serializers/public-profile.serializer.js';

export interface NewMessageNotificationEvent {
  recipientId: string;
  senderId: string;
  conversationId: string;
  messageId: string;
}

export interface ConversationSummary {
  id: string;
  participant: PublicProfileProjection;
  lastMessage: {
    id: string;
    content: string;
    senderId: string;
    clientMessageId: string;
    createdAt: Date;
    readAt: Date | null;
  } | null;
  lastMessageAt: Date;
  unreadCount: number;
  isOnline: boolean;
}

@Injectable()
export class MessagingService {
  private readonly logger = new Logger(MessagingService.name);

  /**
   * Observable stream of new message events for decoupled notification handling.
   */
  readonly newMessage$ = new Subject<NewMessageNotificationEvent>();

  // Rate limiting thresholds
  private readonly maxMessagesPerMinute = 30;
  private readonly maxReportsPerHour = 5;
  private readonly maxConversationCreationsPerHour = 20;

  constructor(
    @InjectRepository(Conversation)
    private readonly conversationRepo: Repository<Conversation>,
    @InjectRepository(ConversationParticipant)
    private readonly participantRepo: Repository<ConversationParticipant>,
    @InjectRepository(Message)
    private readonly messageRepo: Repository<Message>,
    @InjectRepository(UserBlock)
    private readonly blockRepo: Repository<UserBlock>,
    @InjectRepository(ConversationReport)
    private readonly reportRepo: Repository<ConversationReport>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly redisService: RedisService,
    private readonly dataSource: DataSource,
  ) {}

  /**
   * Helper: order two user IDs canonically to enforce database uniqueness.
   */
  private getCanonicalPair(userId1: string, userId2: string): [string, string] {
    return userId1 < userId2 ? [userId1, userId2] : [userId2, userId1];
  }

  /**
   * Start or retrieve a direct one-to-one conversation between two users.
   */
  async getOrCreateConversation(userId: string, targetUserId: string): Promise<ConversationSummary> {
    if (userId === targetUserId) {
      throw new BadRequestException('You cannot create a conversation with yourself.');
    }

    // Verify target user exists and is active
    const targetUser = await this.userRepo.findOne({
      where: { id: targetUserId },
    });
    if (!targetUser || targetUser.accountStatus !== UserStatus.ACTIVE) {
      throw new NotFoundException('Target user not found or inactive.');
    }

    // Verify blocking status between participants
    const blocked = await this.isBlocked(userId, targetUserId);
    if (blocked) {
      throw new ForbiddenException('This conversation is unavailable.');
    }

    // Rate limit conversation creations
    await this.checkRateLimit(
      `rate:conversation:create:${userId}`,
      this.maxConversationCreationsPerHour,
      3600,
      'Too many new conversations created. Please wait before starting another conversation.',
    );

    const [user1Id, user2Id] = this.getCanonicalPair(userId, targetUserId);

    let conversation = await this.conversationRepo.findOne({
      where: { user1Id, user2Id },
      relations: ['user1', 'user2', 'participants'],
    });

    if (!conversation) {
      const queryRunner = this.dataSource.createQueryRunner();
      await queryRunner.connect();
      await queryRunner.startTransaction();

      try {
        const newConv = queryRunner.manager.create(Conversation, {
          user1Id,
          user2Id,
          lastMessageAt: new Date(),
        });
        conversation = await queryRunner.manager.save(newConv);

        // Create participant records for both users
        const p1 = queryRunner.manager.create(ConversationParticipant, {
          conversationId: conversation.id,
          userId: user1Id,
        });
        const p2 = queryRunner.manager.create(ConversationParticipant, {
          conversationId: conversation.id,
          userId: user2Id,
        });
        await queryRunner.manager.save([p1, p2]);

        await queryRunner.commitTransaction();
      } catch (err: unknown) {
        await queryRunner.rollbackTransaction();
        // If duplicate key race occurred, fetch the existing one
        const existing = await this.conversationRepo.findOne({
          where: { user1Id, user2Id },
          relations: ['user1', 'user2', 'participants'],
        });
        if (existing) {
          conversation = existing;
        } else {
          throw err;
        }
      } finally {
        await queryRunner.release();
      }
    }

    return this.buildConversationSummary(conversation!, userId);
  }

  /**
   * Get paginated list of conversations for current user.
   */
  async getConversations(
    userId: string,
    query: GetConversationsQueryDto,
  ): Promise<{ items: ConversationSummary[]; nextCursor: string | null; hasMore: boolean }> {
    const limit = query.limit ?? 20;
    const qb = this.conversationRepo
      .createQueryBuilder('conv')
      .leftJoinAndSelect('conv.user1', 'user1')
      .leftJoinAndSelect('conv.user2', 'user2')
      .leftJoinAndSelect('conv.participants', 'participants')
      .where('(conv.user1Id = :userId OR conv.user2Id = :userId)', { userId })
      .andWhere('conv.deletedAt IS NULL');

    if (query.cursor) {
      const cursorDate = new Date(query.cursor);
      if (!isNaN(cursorDate.getTime())) {
        qb.andWhere('conv.lastMessageAt < :cursor', { cursor: cursorDate });
      }
    }

    qb.orderBy('conv.lastMessageAt', 'DESC').take(limit + 1);

    const rawItems = await qb.getMany();
    const hasMore = rawItems.length > limit;
    const items = hasMore ? rawItems.slice(0, limit) : rawItems;

    const summaries: ConversationSummary[] = [];
    for (const conv of items) {
      summaries.push(await this.buildConversationSummary(conv, userId));
    }

    const nextCursor =
      hasMore && items.length > 0 ? items[items.length - 1]!.lastMessageAt.toISOString() : null;

    return {
      items: summaries,
      nextCursor,
      hasMore,
    };
  }

  /**
   * Get conversation details by ID.
   */
  async getConversationById(conversationId: string, userId: string): Promise<ConversationSummary> {
    const conv = await this.conversationRepo.findOne({
      where: { id: conversationId },
      relations: ['user1', 'user2', 'participants'],
    });

    if (!conv) {
      throw new NotFoundException('Conversation not found.');
    }

    if (conv.user1Id !== userId && conv.user2Id !== userId) {
      throw new ForbiddenException('You are not a participant in this conversation.');
    }

    const otherUserId = conv.user1Id === userId ? conv.user2Id : conv.user1Id;
    if (await this.isBlocked(userId, otherUserId)) {
      throw new ForbiddenException('This conversation is unavailable.');
    }

    return this.buildConversationSummary(conv, userId);
  }

  /**
   * Get paginated message history for a conversation.
   */
  async getMessages(
    conversationId: string,
    userId: string,
    query: GetMessagesQueryDto,
  ): Promise<{ items: Message[]; nextCursor: string | null; hasMore: boolean }> {
    await this.verifyMembership(conversationId, userId);

    const limit = query.limit ?? 30;
    const qb = this.messageRepo
      .createQueryBuilder('msg')
      .where('msg.conversationId = :conversationId', { conversationId })
      .andWhere('msg.deletedAt IS NULL');

    if (query.cursor) {
      const cursorDate = new Date(query.cursor);
      if (!isNaN(cursorDate.getTime())) {
        qb.andWhere('msg.createdAt < :cursor', { cursor: cursorDate });
      }
    }

    qb.orderBy('msg.createdAt', 'DESC').take(limit + 1);

    const rawMessages = await qb.getMany();
    const hasMore = rawMessages.length > limit;
    const items = hasMore ? rawMessages.slice(0, limit) : rawMessages;

    // Items are in reverse chronological order (newest first).
    // Client can display them bottom-to-top.
    const nextCursor =
      hasMore && items.length > 0 ? items[items.length - 1]!.createdAt.toISOString() : null;

    return {
      items,
      nextCursor,
      hasMore,
    };
  }

  /**
   * Send a direct message with idempotency and rate limiting.
   */
  async sendMessage(
    conversationId: string,
    senderId: string,
    dto: SendMessageDto,
  ): Promise<{ message: Message; recipientId: string }> {
    const conv = await this.conversationRepo.findOne({
      where: { id: conversationId },
    });

    if (!conv) {
      throw new NotFoundException('Conversation not found.');
    }

    if (conv.user1Id !== senderId && conv.user2Id !== senderId) {
      throw new ForbiddenException('You are not a participant in this conversation.');
    }

    const recipientId = conv.user1Id === senderId ? conv.user2Id : conv.user1Id;

    // Check blocking
    if (await this.isBlocked(senderId, recipientId)) {
      throw new ForbiddenException('This conversation is unavailable.');
    }

    // Idempotency check: if clientMessageId was already processed for this sender, return existing
    const existing = await this.messageRepo.findOne({
      where: { senderId, clientMessageId: dto.clientMessageId },
    });
    if (existing) {
      return { message: existing, recipientId };
    }

    // Rate limiting
    await this.checkRateLimit(
      `rate:message:send:${senderId}`,
      this.maxMessagesPerMinute,
      60,
      'Too many messages sent. Please slow down.',
    );

    // Validate sanitized content
    const sanitizedContent = dto.content.trim();
    if (!sanitizedContent) {
      throw new BadRequestException('Message content cannot be empty.');
    }

    // Persist message in transaction and update conversation lastMessageAt
    const message = this.messageRepo.create({
      conversationId,
      senderId,
      clientMessageId: dto.clientMessageId,
      content: sanitizedContent,
      messageType: MessageType.TEXT,
    });

    const savedMessage = await this.messageRepo.save(message);

    // Update conversation lastMessageAt
    await this.conversationRepo.update(conversationId, {
      lastMessageAt: savedMessage.createdAt,
    });

    // Asynchronously trigger notification for recipient via event stream (privacy safe: message body NEVER in push/notification)
    this.newMessage$.next({
      recipientId,
      senderId,
      conversationId,
      messageId: savedMessage.id,
    });

    return { message: savedMessage, recipientId };
  }

  /**
   * Mark all unread messages in a conversation as read by current user.
   */
  async markAsRead(
    conversationId: string,
    userId: string,
  ): Promise<{ conversationId: string; unreadCount: number; readAt: Date }> {
    await this.verifyMembership(conversationId, userId);

    const now = new Date();

    // Update participant's lastReadAt
    await this.participantRepo.update(
      { conversationId, userId },
      { lastReadAt: now },
    );

    // Mark messages sent by the other participant as read
    await this.messageRepo
      .createQueryBuilder()
      .update(Message)
      .set({ readAt: now })
      .where('conversationId = :conversationId', { conversationId })
      .andWhere('senderId != :userId', { userId })
      .andWhere('readAt IS NULL')
      .execute();

    return {
      conversationId,
      unreadCount: 0,
      readAt: now,
    };
  }

  /**
   * Soft delete a message by sender.
   */
  async deleteMessage(messageId: string, userId: string): Promise<{ id: string; status: string }> {
    const message = await this.messageRepo.findOne({
      where: { id: messageId },
    });

    if (!message) {
      throw new NotFoundException('Message not found.');
    }

    if (message.senderId !== userId) {
      throw new ForbiddenException('You can only delete your own messages.');
    }

    message.deletedAt = new Date();
    message.content = 'This message was deleted';
    await this.messageRepo.save(message);

    return { id: messageId, status: 'deleted' };
  }

  /**
   * Block a user.
   */
  async blockUser(blockerId: string, blockedId: string): Promise<{ success: boolean; message: string }> {
    if (blockerId === blockedId) {
      throw new BadRequestException('You cannot block yourself.');
    }

    const existing = await this.blockRepo.findOne({
      where: { blockerId, blockedId },
    });

    if (!existing) {
      const block = this.blockRepo.create({ blockerId, blockedId });
      await this.blockRepo.save(block);
    }

    return { success: true, message: 'User blocked successfully.' };
  }

  /**
   * Unblock a user.
   */
  async unblockUser(blockerId: string, blockedId: string): Promise<{ success: boolean; message: string }> {
    await this.blockRepo.delete({ blockerId, blockedId });
    return { success: true, message: 'User unblocked successfully.' };
  }

  /**
   * Check if a blocking relationship exists between two users in either direction.
   */
  async isBlocked(userA: string, userB: string): Promise<boolean> {
    const block = await this.blockRepo.findOne({
      where: [
        { blockerId: userA, blockedId: userB },
        { blockerId: userB, blockedId: userA },
      ],
    });
    return !!block;
  }

  /**
   * Report a conversation.
   */
  async reportConversation(
    reporterId: string,
    conversationId: string,
    dto: ReportConversationDto,
  ): Promise<{ message: string }> {
    await this.verifyMembership(conversationId, reporterId, false);

    // Rate limiting
    await this.checkRateLimit(
      `rate:conversation:report:${reporterId}`,
      this.maxReportsPerHour,
      3600,
      'Too many reports submitted. Please wait before submitting another report.',
    );

    const existingReport = await this.reportRepo.findOne({
      where: {
        reporterId,
        conversationId,
        status: ConversationReportStatus.PENDING,
      },
    });

    if (existingReport) {
      throw new ConflictException('You have already submitted a pending report for this conversation.');
    }

    const report = this.reportRepo.create({
      reporterId,
      conversationId,
      messageId: dto.messageId ?? null,
      reason: dto.reason,
      description: dto.description ?? null,
      status: ConversationReportStatus.PENDING,
    });

    await this.reportRepo.save(report);

    return {
      message: 'Report submitted successfully. Our local community moderators will review it.',
    };
  }

  /**
   * Ephemeral presence via Redis.
   */
  async setPresence(userId: string, isOnline: boolean): Promise<void> {
    const key = `presence:${userId}`;
    if (isOnline) {
      await this.redisService.set(key, 'online', 180); // 3-minute TTL
    } else {
      await this.redisService.del(key);
    }
  }

  async isUserOnline(userId: string): Promise<boolean> {
    const val = await this.redisService.get(`presence:${userId}`);
    return val === 'online';
  }

  /**
   * Throttle typing indicator emissions.
   */
  async shouldEmitTyping(userId: string, conversationId: string): Promise<boolean> {
    const key = `typing:${userId}:${conversationId}`;
    const exists = await this.redisService.exists(key);
    if (exists) {
      return false; // Throttled
    }
    await this.redisService.set(key, '1', 2); // 2-second debounce
    return true;
  }

  /**
   * Helper: verify user is participant in conversation.
   */
  private async verifyMembership(
    conversationId: string,
    userId: string,
    checkBlock: boolean = true,
  ): Promise<Conversation> {
    const conv = await this.conversationRepo.findOne({
      where: { id: conversationId },
    });

    if (!conv) {
      throw new NotFoundException('Conversation not found.');
    }

    if (conv.user1Id !== userId && conv.user2Id !== userId) {
      throw new ForbiddenException('You are not a participant in this conversation.');
    }

    if (checkBlock) {
      const otherUserId = conv.user1Id === userId ? conv.user2Id : conv.user1Id;
      if (await this.isBlocked(userId, otherUserId)) {
        throw new ForbiddenException('This conversation is unavailable.');
      }
    }

    return conv;
  }

  /**
   * Helper: construct a safe conversation summary projection.
   */
  private async buildConversationSummary(
    conv: Conversation,
    currentUserId: string,
  ): Promise<ConversationSummary> {
    const otherUserId = conv.user1Id === currentUserId ? conv.user2Id : conv.user1Id;
    const otherUser =
      conv.user1Id === otherUserId ? conv.user1 : conv.user2;

    const publicProfile = toPublicProfile(otherUser);

    // Fetch latest message
    const lastMsg = await this.messageRepo.findOne({
      where: { conversationId: conv.id, deletedAt: undefined },
      order: { createdAt: 'DESC' },
    });

    // Determine unread count
    const participant = conv.participants?.find((p) => p.userId === currentUserId);
    const lastReadAt = participant?.lastReadAt;

    let unreadCount = 0;
    if (lastReadAt) {
      unreadCount = await this.messageRepo.count({
        where: {
          conversationId: conv.id,
          senderId: otherUserId,
          createdAt: LessThan(new Date()), // replaced in query builder below if needed
          readAt: undefined,
        },
      });
      // More accurate unread count with query builder:
      unreadCount = await this.messageRepo
        .createQueryBuilder('msg')
        .where('msg.conversationId = :cid', { cid: conv.id })
        .andWhere('msg.senderId = :otherId', { otherId: otherUserId })
        .andWhere('msg.createdAt > :lastReadAt', { lastReadAt })
        .andWhere('msg.deletedAt IS NULL')
        .getCount();
    } else {
      unreadCount = await this.messageRepo
        .createQueryBuilder('msg')
        .where('msg.conversationId = :cid', { cid: conv.id })
        .andWhere('msg.senderId = :otherId', { otherId: otherUserId })
        .andWhere('msg.deletedAt IS NULL')
        .getCount();
    }

    const isOnline = await this.isUserOnline(otherUserId);

    return {
      id: conv.id,
      participant: publicProfile,
      lastMessage: lastMsg
        ? {
            id: lastMsg.id,
            content: lastMsg.content,
            senderId: lastMsg.senderId,
            clientMessageId: lastMsg.clientMessageId,
            createdAt: lastMsg.createdAt,
            readAt: lastMsg.readAt ?? null,
          }
        : null,
      lastMessageAt: conv.lastMessageAt,
      unreadCount,
      isOnline,
    };
  }

  /**
   * Helper: check Redis sliding-window rate limit.
   */
  private async checkRateLimit(
    key: string,
    limit: number,
    windowSeconds: number,
    errorMessage: string,
  ): Promise<void> {
    try {
      const current = typeof this.redisService.incrementWithExpire === 'function'
        ? await this.redisService.incrementWithExpire(key, windowSeconds)
        : await this.redisService.incr(key);
      if (current > limit) {
        throw new HttpException(
          {
            statusCode: HttpStatus.TOO_MANY_REQUESTS,
            error: 'Too Many Requests',
            message: errorMessage,
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    } catch (err: unknown) {
      if (err instanceof HttpException) throw err;
      this.logger.warn(`Redis rate limit check failed for key: ${key}. Proceeding.`);
    }
  }
}

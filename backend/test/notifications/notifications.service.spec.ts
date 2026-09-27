import { describe, it, expect, beforeEach, vi } from 'vitest';
import { NotificationsService } from '../../src/modules/notifications/notifications.service.js';
import { NotificationType } from '../../src/modules/notifications/enums/notification-type.enum.js';
import { NotificationCategory } from '../../src/modules/notifications/enums/notification-category.enum.js';
import { DevicePlatform } from '../../src/modules/notifications/entities/device-token.entity.js';
import { NotFoundException } from '@nestjs/common';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let mockNotificationRepo: any;
  let mockDeviceTokenRepo: any;
  let mockPreferenceRepo: any;
  let mockPushProvider: any;
  let mockMessagingGateway: any;

  beforeEach(() => {
    mockNotificationRepo = {
      findOne: vi.fn(),
      find: vi.fn(),
      create: vi.fn((data: any) => ({ id: 'notif-1', ...data, createdAt: new Date() })),
      save: vi.fn((data: any) => Promise.resolve({ id: 'notif-1', ...data, createdAt: new Date() })),
      count: vi.fn().mockResolvedValue(1),
      softDelete: vi.fn().mockResolvedValue({ affected: 1 }),
      createQueryBuilder: vi.fn(),
    };

    mockDeviceTokenRepo = {
      findOne: vi.fn(),
      find: vi.fn().mockResolvedValue([]),
      create: vi.fn((data: any) => ({ id: 'token-1', ...data })),
      save: vi.fn((data: any) => Promise.resolve({ id: 'token-1', ...data })),
    };

    mockPreferenceRepo = {
      findOne: vi.fn(),
      create: vi.fn((data: any) => ({ id: 'pref-1', ...data })),
      save: vi.fn((data: any) => Promise.resolve({ id: 'pref-1', ...data })),
    };

    mockPushProvider = {
      isAvailable: vi.fn().mockReturnValue(true),
      getProviderName: vi.fn().mockReturnValue('FCM'),
      send: vi.fn().mockResolvedValue({ success: true, messageId: 'msg-1' }),
      sendMulticast: vi.fn().mockResolvedValue([]),
    };

    mockMessagingGateway = {
      emitToUser: vi.fn(),
    };

    service = new NotificationsService(
      mockNotificationRepo,
      mockDeviceTokenRepo,
      mockPreferenceRepo,
      mockPushProvider,
      mockMessagingGateway,
    );
  });

  describe('createAndSend', () => {
    it('should suppress notification if user has category disabled', async () => {
      mockPreferenceRepo.findOne.mockResolvedValue({
        userId: 'usr-1',
        socialEnabled: false,
        pushEnabled: true,
      });

      const result = await service.createAndSend({
        recipientId: 'usr-1',
        type: NotificationType.POST_LIKED,
        category: NotificationCategory.SOCIAL,
        title: 'Liked',
        body: 'Post liked',
      });

      expect(result).toBeNull();
      expect(mockNotificationRepo.save).not.toHaveBeenCalled();
    });

    it('should suppress duplicate notification if deduplicationKey exists', async () => {
      mockPreferenceRepo.findOne.mockResolvedValue({
        userId: 'usr-1',
        messagesEnabled: true,
        pushEnabled: true,
      });

      const existingNotif = { id: 'existing-1', deduplicationKey: 'msg:123' };
      mockNotificationRepo.findOne.mockResolvedValue(existingNotif);

      const result = await service.createAndSend({
        recipientId: 'usr-1',
        type: NotificationType.MESSAGE_RECEIVED,
        category: NotificationCategory.MESSAGES,
        title: 'New message',
        body: 'Secret message body',
        deduplicationKey: 'msg:123',
      });

      expect(result).toEqual(existingNotif);
      expect(mockNotificationRepo.save).not.toHaveBeenCalled();
    });

    it('should persist notification, emit socket events, and dispatch sanitized push', async () => {
      mockPreferenceRepo.findOne.mockResolvedValue({
        userId: 'usr-1',
        messagesEnabled: true,
        pushEnabled: true,
      });

      mockNotificationRepo.findOne.mockResolvedValue(null);
      mockDeviceTokenRepo.find.mockResolvedValue([
        { id: 'dt-1', token: 'fcm-token-1', isActive: true, userId: 'usr-1' },
      ]);

      const result = await service.createAndSend({
        recipientId: 'usr-1',
        senderId: 'usr-2',
        type: NotificationType.MESSAGE_RECEIVED,
        category: NotificationCategory.MESSAGES,
        title: 'Sujeet',
        body: 'Super secret private message content',
        deepLink: '/chat/c1',
        deduplicationKey: 'msg:new',
      });

      expect(result).toBeDefined();
      expect(mockNotificationRepo.save).toHaveBeenCalled();
      expect(mockMessagingGateway.emitToUser).toHaveBeenCalled();

      // Verify privacy safeguard: raw body is NOT sent in push
      expect(mockPushProvider.send).toHaveBeenCalledWith(
        expect.objectContaining({
          token: 'fcm-token-1',
          body: 'You have received a new message',
        }),
      );
    });

    it('should deactivate invalid tokens when push provider reports invalidToken', async () => {
      mockPreferenceRepo.findOne.mockResolvedValue({
        userId: 'usr-1',
        systemEnabled: true,
        pushEnabled: true,
      });

      const deadTokenRecord = {
        id: 'dt-dead',
        token: 'dead-token',
        isActive: true,
        userId: 'usr-1',
      };
      mockDeviceTokenRepo.find.mockResolvedValue([deadTokenRecord]);
      mockPushProvider.send.mockResolvedValue({ success: false, invalidToken: true });

      await service.createAndSend({
        recipientId: 'usr-1',
        type: NotificationType.SYSTEM_ALERT,
        category: NotificationCategory.SYSTEM,
        title: 'Maintenance',
        body: 'Scheduled maintenance',
      });

      expect(deadTokenRecord.isActive).toBe(false);
      expect(mockDeviceTokenRepo.save).toHaveBeenCalledWith(deadTokenRecord);
    });
  });

  describe('markAsRead and markAllAsRead', () => {
    it('should mark single notification as read and emit socket event', async () => {
      const notif = { id: 'notif-1', recipientId: 'usr-1', isRead: false, readAt: null };
      mockNotificationRepo.findOne.mockResolvedValue(notif);

      const result = await service.markAsRead('usr-1', 'notif-1');
      expect(result.isRead).toBe(true);
      expect(result.readAt).toBeDefined();
      expect(mockMessagingGateway.emitToUser).toHaveBeenCalled();
    });

    it('should throw NotFoundException if notification not found', async () => {
      mockNotificationRepo.findOne.mockResolvedValue(null);
      await expect(service.markAsRead('usr-1', 'nonexistent')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should mark all notifications as read and emit 0 unread count', async () => {
      mockNotificationRepo.find.mockResolvedValue([{ id: 'n1' }, { id: 'n2' }]);
      mockNotificationRepo.createQueryBuilder.mockReturnValue({
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        execute: vi.fn().mockResolvedValue({ affected: 2 }),
      });

      const res = await service.markAllAsRead('usr-1');
      expect(res.updatedCount).toBe(2);
      expect(mockMessagingGateway.emitToUser).toHaveBeenCalledWith(
        'usr-1',
        'notification:unread-count',
        { count: 0 },
      );
    });
  });

  describe('deleteNotification', () => {
    it('should soft-delete notification and update unread count if it was unread', async () => {
      const notif = { id: 'notif-1', recipientId: 'usr-1', isRead: false };
      mockNotificationRepo.findOne.mockResolvedValue(notif);

      await service.deleteNotification('usr-1', 'notif-1');
      expect(mockNotificationRepo.softDelete).toHaveBeenCalledWith({
        id: 'notif-1',
        recipientId: 'usr-1',
      });
      expect(mockMessagingGateway.emitToUser).toHaveBeenCalledWith(
        'usr-1',
        'notification:unread-count',
        { count: 1 },
      );
    });

    it('should throw NotFoundException if deleting non-existent notification', async () => {
      mockNotificationRepo.findOne.mockResolvedValue(null);
      await expect(service.deleteNotification('usr-1', 'missing')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('device token registration and unregistration', () => {
    it('should register a new device token', async () => {
      mockDeviceTokenRepo.findOne.mockResolvedValue(null);

      const token = await service.registerDevice('usr-1', {
        token: 'new-token',
        platform: DevicePlatform.ANDROID,
      });

      expect(token).toBeDefined();
      expect(mockDeviceTokenRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'usr-1',
          token: 'new-token',
          platform: DevicePlatform.ANDROID,
          isActive: true,
        }),
      );
    });

    it('should update an existing device token', async () => {
      const existing = {
        id: 't-1',
        token: 'existing-token',
        userId: 'other-user',
        isActive: false,
      };
      mockDeviceTokenRepo.findOne.mockResolvedValue(existing);

      const token = await service.registerDevice('usr-1', {
        token: 'existing-token',
        platform: DevicePlatform.ANDROID,
      });

      expect(existing.userId).toBe('usr-1');
      expect(existing.isActive).toBe(true);
      expect(mockDeviceTokenRepo.save).toHaveBeenCalledWith(existing);
    });

    it('should unregister a device token upon logout', async () => {
      const existing = {
        id: 't-1',
        token: 'logout-token',
        userId: 'usr-1',
        isActive: true,
      };
      mockDeviceTokenRepo.findOne.mockResolvedValue(existing);

      await service.unregisterDevice('usr-1', 'logout-token');
      expect(existing.isActive).toBe(false);
      expect(mockDeviceTokenRepo.save).toHaveBeenCalledWith(existing);
    });
  });

  describe('preferences', () => {
    it('should return default preferences if none exist', async () => {
      mockPreferenceRepo.findOne.mockResolvedValue(null);

      const prefs = await service.getPreferences('usr-1');
      expect(prefs).toBeDefined();
      expect(mockPreferenceRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'usr-1',
          messagesEnabled: true,
          pushEnabled: true,
        }),
      );
    });

    it('should update preferences selectively', async () => {
      const existing = {
        userId: 'usr-1',
        messagesEnabled: true,
        socialEnabled: true,
        pushEnabled: true,
      };
      mockPreferenceRepo.findOne.mockResolvedValue(existing);

      await service.updatePreferences('usr-1', {
        socialEnabled: false,
      });

      expect(existing.socialEnabled).toBe(false);
      expect(existing.messagesEnabled).toBe(true);
      expect(mockPreferenceRepo.save).toHaveBeenCalledWith(existing);
    });
  });
});

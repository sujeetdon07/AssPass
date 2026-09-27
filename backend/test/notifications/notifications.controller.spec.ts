import { describe, it, expect, beforeEach, vi } from 'vitest';
import { NotificationsController } from '../../src/modules/notifications/notifications.controller.js';
import { NotificationsService } from '../../src/modules/notifications/notifications.service.js';
import { DevicePlatform } from '../../src/modules/notifications/entities/device-token.entity.js';

describe('NotificationsController', () => {
  let controller: NotificationsController;
  let mockService: any;

  const currentUser = {
    userId: 'usr-1111',
    sessionId: 'sess-1',
    phoneNumber: '+919876543210',
    onboarding: true,
  };

  beforeEach(() => {
    mockService = {
      getNotifications: vi.fn().mockResolvedValue({
        items: [],
        nextCursor: null,
        hasMore: false,
      }),
      getUnreadCount: vi.fn().mockResolvedValue(3),
      markAsRead: vi.fn().mockResolvedValue({ id: 'notif-1', isRead: true }),
      markAllAsRead: vi.fn().mockResolvedValue({ updatedCount: 5 }),
      deleteNotification: vi.fn().mockResolvedValue(undefined),
      registerDevice: vi.fn().mockResolvedValue({
        id: 'dev-1',
        platform: DevicePlatform.ANDROID,
        isActive: true,
        lastUsedAt: new Date(),
      }),
      unregisterDevice: vi.fn().mockResolvedValue(undefined),
      getPreferences: vi.fn().mockResolvedValue({
        messagesEnabled: true,
        socialEnabled: true,
        communityEnabled: true,
        marketplaceEnabled: true,
        businessEnabled: true,
        systemEnabled: true,
        pushEnabled: true,
        emailEnabled: false,
        smsEnabled: false,
      }),
      updatePreferences: vi.fn().mockResolvedValue({
        messagesEnabled: false,
        socialEnabled: true,
        communityEnabled: true,
        marketplaceEnabled: true,
        businessEnabled: true,
        systemEnabled: true,
        pushEnabled: true,
        emailEnabled: false,
        smsEnabled: false,
      }),
    };

    controller = new NotificationsController(mockService as unknown as NotificationsService);
  });

  it('should call getNotifications with current user and query', async () => {
    const res = await controller.getNotifications(currentUser, { limit: 10, unreadOnly: true });
    expect(res.items).toEqual([]);
    expect(mockService.getNotifications).toHaveBeenCalledWith('usr-1111', {
      limit: 10,
      unreadOnly: true,
    });
  });

  it('should call getUnreadCount and return wrapped count', async () => {
    const res = await controller.getUnreadCount(currentUser);
    expect(res).toEqual({ count: 3 });
    expect(mockService.getUnreadCount).toHaveBeenCalledWith('usr-1111');
  });

  it('should call markAsRead with notification ID', async () => {
    const res = await controller.markAsRead(currentUser, 'notif-1');
    expect(res.isRead).toBe(true);
    expect(mockService.markAsRead).toHaveBeenCalledWith('usr-1111', 'notif-1');
  });

  it('should call deleteNotification with notification ID', async () => {
    const res = await controller.deleteNotification(currentUser, 'notif-1');
    expect(res).toEqual({ success: true });
    expect(mockService.deleteNotification).toHaveBeenCalledWith('usr-1111', 'notif-1');
  });

  it('should call markAllAsRead for user', async () => {
    const res = await controller.markAllAsRead(currentUser);
    expect(res.updatedCount).toBe(5);
    expect(mockService.markAllAsRead).toHaveBeenCalledWith('usr-1111');
  });

  it('should call registerDevice and return device metadata', async () => {
    const res = await controller.registerDevice(currentUser, {
      token: 'fcm-token-xyz',
      platform: DevicePlatform.ANDROID,
    });
    expect(res.id).toBe('dev-1');
    expect(res.isActive).toBe(true);
    expect(mockService.registerDevice).toHaveBeenCalledWith('usr-1111', {
      token: 'fcm-token-xyz',
      platform: DevicePlatform.ANDROID,
    });
  });

  it('should call unregisterDevice for token', async () => {
    const res = await controller.unregisterDevice(currentUser, 'fcm-token-xyz');
    expect(res).toEqual({ success: true });
    expect(mockService.unregisterDevice).toHaveBeenCalledWith('usr-1111', 'fcm-token-xyz');
  });

  it('should get and serialize user preferences', async () => {
    const res = await controller.getPreferences(currentUser);
    expect(res.messagesEnabled).toBe(true);
    expect(mockService.getPreferences).toHaveBeenCalledWith('usr-1111');
  });

  it('should update and serialize user preferences', async () => {
    const res = await controller.updatePreferences(currentUser, { messagesEnabled: false });
    expect(res.messagesEnabled).toBe(false);
    expect(mockService.updatePreferences).toHaveBeenCalledWith('usr-1111', {
      messagesEnabled: false,
    });
  });
});

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { MessagingController } from '../../src/modules/messaging/messaging.controller.js';
import { MessagingService } from '../../src/modules/messaging/messaging.service.js';
import { ConversationReportReason } from '../../src/modules/messaging/entities/conversation-report.entity.js';

describe('MessagingController', () => {
  let controller: MessagingController;
  let mockService: any;

  const currentUser = {
    userId: 'usr-1111',
    sessionId: 'sess-1',
    phoneNumber: '+919876543210',
    onboarding: true,
  };

  beforeEach(() => {
    mockService = {
      getOrCreateConversation: vi.fn().mockResolvedValue({ id: 'conv-1' }),
      getConversations: vi.fn().mockResolvedValue({ items: [], nextCursor: null, hasMore: false }),
      getConversationById: vi.fn().mockResolvedValue({ id: 'conv-1' }),
      getMessages: vi.fn().mockResolvedValue({ items: [], nextCursor: null, hasMore: false }),
      sendMessage: vi.fn().mockResolvedValue({ message: { id: 'msg-1' } }),
      markAsRead: vi.fn().mockResolvedValue({ conversationId: 'conv-1', unreadCount: 0 }),
      deleteMessage: vi.fn().mockResolvedValue({ id: 'msg-1', status: 'deleted' }),
      reportConversation: vi.fn().mockResolvedValue({ message: 'Report submitted' }),
      blockUser: vi.fn().mockResolvedValue({ success: true, message: 'User blocked' }),
      unblockUser: vi.fn().mockResolvedValue({ success: true, message: 'User unblocked' }),
      isUserOnline: vi.fn().mockResolvedValue(true),
    };

    controller = new MessagingController(mockService as unknown as MessagingService);
  });

  it('should call getOrCreateConversation with authenticated user and participantId', async () => {
    const res = await controller.createOrGetConversation(currentUser, { participantId: 'usr-2222' });
    expect(res).toEqual({ id: 'conv-1' });
    expect(mockService.getOrCreateConversation).toHaveBeenCalledWith('usr-1111', 'usr-2222');
  });

  it('should call getConversations with current user and query', async () => {
    const res = await controller.getConversations(currentUser, { limit: 15 });
    expect(res.items).toEqual([]);
    expect(mockService.getConversations).toHaveBeenCalledWith('usr-1111', { limit: 15 });
  });

  it('should call getConversationById', async () => {
    const res = await controller.getConversationById('conv-1', currentUser);
    expect(res.id).toBe('conv-1');
    expect(mockService.getConversationById).toHaveBeenCalledWith('conv-1', 'usr-1111');
  });

  it('should call getMessages with pagination query', async () => {
    const res = await controller.getMessages('conv-1', currentUser, { limit: 20 });
    expect(res.items).toEqual([]);
    expect(mockService.getMessages).toHaveBeenCalledWith('conv-1', 'usr-1111', { limit: 20 });
  });

  it('should call sendMessage via REST fallback', async () => {
    const res = await controller.sendMessage('conv-1', currentUser, {
      clientMessageId: 'cid-1',
      content: 'Hey there',
    });
    expect(res).toEqual({ id: 'msg-1' });
    expect(mockService.sendMessage).toHaveBeenCalledWith('conv-1', 'usr-1111', {
      clientMessageId: 'cid-1',
      content: 'Hey there',
    });
  });

  it('should call markAsRead', async () => {
    const res = await controller.markAsRead('conv-1', currentUser);
    expect(res.unreadCount).toBe(0);
    expect(mockService.markAsRead).toHaveBeenCalledWith('conv-1', 'usr-1111');
  });

  it('should call deleteMessage', async () => {
    const res = await controller.deleteMessage('msg-1', currentUser);
    expect(res.status).toBe('deleted');
    expect(mockService.deleteMessage).toHaveBeenCalledWith('msg-1', 'usr-1111');
  });

  it('should call reportConversation', async () => {
    const res = await controller.reportConversation('conv-1', currentUser, {
      reason: ConversationReportReason.SPAM,
      description: 'Spamming products',
    });
    expect(res.message).toBe('Report submitted');
    expect(mockService.reportConversation).toHaveBeenCalledWith('usr-1111', 'conv-1', {
      reason: ConversationReportReason.SPAM,
      description: 'Spamming products',
    });
  });

  it('should call blockUser and unblockUser', async () => {
    const blockRes = await controller.blockUser(currentUser, { userId: 'usr-bad' });
    expect(blockRes.success).toBe(true);
    expect(mockService.blockUser).toHaveBeenCalledWith('usr-1111', 'usr-bad');

    const unblockRes = await controller.unblockUser('usr-bad', currentUser);
    expect(unblockRes.success).toBe(true);
    expect(mockService.unblockUser).toHaveBeenCalledWith('usr-1111', 'usr-bad');
  });

  it('should call getPresence', async () => {
    const res = await controller.getPresence('usr-2222');
    expect(res.status).toBe('online');
    expect(mockService.isUserOnline).toHaveBeenCalledWith('usr-2222');
  });
});

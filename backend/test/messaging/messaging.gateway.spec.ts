import { describe, it, expect, beforeEach, vi } from 'vitest';
import { MessagingGateway } from '../../src/modules/messaging/messaging.gateway.js';
import { MessagingEvents } from '../../src/modules/messaging/events/messaging-events.constants.js';

describe('MessagingGateway', () => {
  let gateway: MessagingGateway;
  let mockService: any;
  let mockWsJwtGuard: any;
  let mockClient: any;
  let mockServer: any;

  beforeEach(() => {
    mockService = {
      setPresence: vi.fn().mockResolvedValue(undefined),
      getConversationById: vi.fn().mockResolvedValue({ id: 'conv-1' }),
      sendMessage: vi.fn().mockResolvedValue({
        message: {
          id: 'msg-1',
          conversationId: 'conv-1',
          senderId: 'usr-sender',
          clientMessageId: 'cid-1',
          content: 'Hello via socket',
          messageType: 'TEXT',
          createdAt: new Date(),
          readAt: null,
        },
        recipientId: 'usr-recipient',
      }),
      markAsRead: vi.fn().mockResolvedValue({ conversationId: 'conv-1', unreadCount: 0, readAt: new Date() }),
      shouldEmitTyping: vi.fn().mockResolvedValue(true),
      isUserOnline: vi.fn().mockResolvedValue(true),
    };

    mockWsJwtGuard = {
      authenticateSocket: vi.fn().mockResolvedValue({
        userId: 'usr-sender',
        sessionId: 'sess-1',
        phoneNumber: '+919876543210',
      }),
    };

    mockClient = {
      id: 'socket-123',
      data: {
        user: {
          userId: 'usr-sender',
          sessionId: 'sess-1',
          phoneNumber: '+919876543210',
        },
      },
      join: vi.fn().mockResolvedValue(undefined),
      leave: vi.fn().mockResolvedValue(undefined),
      emit: vi.fn(),
      to: vi.fn().mockReturnThis(),
      disconnect: vi.fn(),
    };

    mockServer = {
      to: vi.fn().mockReturnThis(),
      emit: vi.fn(),
      in: vi.fn(() => ({
        fetchSockets: vi.fn().mockResolvedValue([]),
      })),
    };

    gateway = new MessagingGateway(mockService, mockWsJwtGuard);
    gateway.server = mockServer;
  });

  it('should authenticate client on handleConnection and set online presence', async () => {
    mockClient.data = {};
    await gateway.handleConnection(mockClient);
    expect(mockWsJwtGuard.authenticateSocket).toHaveBeenCalledWith(mockClient);
    expect(mockClient.join).toHaveBeenCalledWith('user:usr-sender');
    expect(mockService.setPresence).toHaveBeenCalledWith('usr-sender', true);
  });

  it('should disconnect unauthorized socket on handleConnection', async () => {
    mockClient.data = {};
    mockWsJwtGuard.authenticateSocket.mockResolvedValueOnce(null);
    await gateway.handleConnection(mockClient);
    expect(mockClient.emit).toHaveBeenCalledWith(MessagingEvents.SERVER_ERROR, {
      message: 'Authentication required.',
    });
    expect(mockClient.disconnect).toHaveBeenCalledWith(true);
  });

  it('should mark user offline on handleDisconnect', async () => {
    await gateway.handleDisconnect(mockClient);
    expect(mockService.setPresence).toHaveBeenCalledWith('usr-sender', false);
  });

  it('should handle join conversation', async () => {
    await gateway.handleJoinConversation(mockClient, { conversationId: 'conv-1' });
    expect(mockService.getConversationById).toHaveBeenCalledWith('conv-1', 'usr-sender');
    expect(mockClient.join).toHaveBeenCalledWith('conv:conv-1');
    expect(mockClient.emit).toHaveBeenCalledWith(MessagingEvents.SERVER_CONVERSATION_JOINED, {
      conversationId: 'conv-1',
    });
  });

  it('should handle message send and emit ack to sender and new message to room', async () => {
    await gateway.handleSendMessage(mockClient, {
      conversationId: 'conv-1',
      clientMessageId: 'cid-1',
      content: 'Hello via socket',
    });

    expect(mockService.sendMessage).toHaveBeenCalledWith('conv-1', 'usr-sender', {
      clientMessageId: 'cid-1',
      content: 'Hello via socket',
    });

    expect(mockClient.emit).toHaveBeenCalledWith(
      MessagingEvents.SERVER_MESSAGE_ACK,
      expect.objectContaining({
        messageId: 'msg-1',
        clientMessageId: 'cid-1',
        status: 'sent',
      }),
    );

    expect(mockClient.to).toHaveBeenCalledWith('conv:conv-1');
    expect(mockServer.to).toHaveBeenCalledWith('user:usr-recipient');
  });

  it('should handle message read', async () => {
    await gateway.handleMessageRead(mockClient, { conversationId: 'conv-1' });
    expect(mockService.markAsRead).toHaveBeenCalledWith('conv-1', 'usr-sender');
    expect(mockClient.to).toHaveBeenCalledWith('conv:conv-1');
  });

  it('should handle typing start when allowed by rate limiter', async () => {
    await gateway.handleTypingStart(mockClient, { conversationId: 'conv-1' });
    expect(mockService.shouldEmitTyping).toHaveBeenCalledWith('usr-sender', 'conv-1');
    expect(mockClient.to).toHaveBeenCalledWith('conv:conv-1');
  });

  it('should handle typing stop', async () => {
    await gateway.handleTypingStop(mockClient, { conversationId: 'conv-1' });
    expect(mockClient.to).toHaveBeenCalledWith('conv:conv-1');
  });

  it('should handle presence subscribe', async () => {
    await gateway.handlePresenceSubscribe(mockClient, { userId: 'usr-other' });
    expect(mockService.isUserOnline).toHaveBeenCalledWith('usr-other');
    expect(mockClient.emit).toHaveBeenCalledWith(MessagingEvents.SERVER_PRESENCE_UPDATE, {
      userId: 'usr-other',
      status: 'online',
    });
  });
});

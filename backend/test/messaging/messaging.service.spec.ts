import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
} from '@nestjs/common';
import { MessagingService } from '../../src/modules/messaging/messaging.service.js';
import { Conversation } from '../../src/modules/messaging/entities/conversation.entity.js';
import { ConversationParticipant } from '../../src/modules/messaging/entities/conversation-participant.entity.js';
import { Message, MessageType } from '../../src/modules/messaging/entities/message.entity.js';
import { UserBlock } from '../../src/modules/messaging/entities/user-block.entity.js';
import {
  ConversationReport,
  ConversationReportReason,
  ConversationReportStatus,
} from '../../src/modules/messaging/entities/conversation-report.entity.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';

describe('MessagingService', () => {
  let service: MessagingService;
  let mockConversationRepo: any;
  let mockParticipantRepo: any;
  let mockMessageRepo: any;
  let mockBlockRepo: any;
  let mockReportRepo: any;
  let mockUserRepo: any;
  let mockRedisService: any;
  let mockDataSource: any;

  const userA: User = {
    id: 'user-a-1111',
    phoneNumber: '+919876543210',
    displayName: 'Aarav Kumar',
    avatarUrl: null,
    accountStatus: UserStatus.ACTIVE,
    onboardingCompleted: true,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: 'Defence Colony',
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const userB: User = {
    id: 'user-b-2222',
    phoneNumber: '+919876543211',
    displayName: 'Diya Patel',
    avatarUrl: null,
    accountStatus: UserStatus.ACTIVE,
    onboardingCompleted: true,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Koramangala',
    neighborhood: '4th Block',
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(() => {
    mockConversationRepo = {
      findOne: vi.fn(),
      find: vi.fn(),
      create: vi.fn((data) => ({ id: 'conv-123', ...data })),
      save: vi.fn((entity) => Promise.resolve({ id: 'conv-123', ...entity })),
      update: vi.fn().mockResolvedValue({ affected: 1 }),
      createQueryBuilder: vi.fn(() => ({
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([]),
      })),
    };

    mockParticipantRepo = {
      findOne: vi.fn(),
      create: vi.fn((data) => ({ id: 'part-1', ...data })),
      save: vi.fn((entities) => Promise.resolve(entities)),
      update: vi.fn().mockResolvedValue({ affected: 1 }),
    };

    mockMessageRepo = {
      findOne: vi.fn(),
      create: vi.fn((data) => ({
        id: 'msg-999',
        createdAt: new Date(),
        updatedAt: new Date(),
        ...data,
      })),
      save: vi.fn((entity) =>
        Promise.resolve({
          id: 'msg-999',
          createdAt: new Date(),
          updatedAt: new Date(),
          ...entity,
        }),
      ),
      count: vi.fn().mockResolvedValue(0),
      createQueryBuilder: vi.fn(() => ({
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([]),
        getCount: vi.fn().mockResolvedValue(0),
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        execute: vi.fn().mockResolvedValue({ affected: 1 }),
      })),
    };

    mockBlockRepo = {
      findOne: vi.fn(),
      create: vi.fn((data) => ({ id: 'block-1', ...data })),
      save: vi.fn((entity) => Promise.resolve(entity)),
      delete: vi.fn().mockResolvedValue({ affected: 1 }),
    };

    mockReportRepo = {
      findOne: vi.fn(),
      create: vi.fn((data) => ({ id: 'rep-1', ...data })),
      save: vi.fn((entity) => Promise.resolve(entity)),
    };

    mockUserRepo = {
      findOne: vi.fn((query) => {
        if (query.where?.id === userA.id) return Promise.resolve(userA);
        if (query.where?.id === userB.id) return Promise.resolve(userB);
        return Promise.resolve(null);
      }),
    };

    mockRedisService = {
      get: vi.fn().mockResolvedValue(null),
      set: vi.fn().mockResolvedValue('OK'),
      del: vi.fn().mockResolvedValue(1),
      exists: vi.fn().mockResolvedValue(false),
      incr: vi.fn().mockResolvedValue(1),
      expire: vi.fn().mockResolvedValue(1),
    };

    mockDataSource = {
      createQueryRunner: vi.fn(() => ({
        connect: vi.fn().mockResolvedValue(undefined),
        startTransaction: vi.fn().mockResolvedValue(undefined),
        commitTransaction: vi.fn().mockResolvedValue(undefined),
        rollbackTransaction: vi.fn().mockResolvedValue(undefined),
        release: vi.fn().mockResolvedValue(undefined),
        manager: {
          create: vi.fn((_type, data) => ({ id: 'conv-123', ...data })),
          save: vi.fn((data) => Promise.resolve(data)),
        },
      })),
    };

    service = new MessagingService(
      mockConversationRepo,
      mockParticipantRepo,
      mockMessageRepo,
      mockBlockRepo,
      mockReportRepo,
      mockUserRepo,
      mockRedisService,
      mockDataSource,
    );
  });

  describe('getOrCreateConversation', () => {
    it('should reject self-conversation with BadRequestException', async () => {
      await expect(service.getOrCreateConversation('usr-1', 'usr-1')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should reject non-existent or inactive target user with NotFoundException', async () => {
      mockUserRepo.findOne.mockResolvedValueOnce(null);
      await expect(service.getOrCreateConversation(userA.id, 'missing-user')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should reject conversation if blocked with ForbiddenException', async () => {
      mockBlockRepo.findOne.mockResolvedValueOnce({ id: 'block-1', blockerId: userB.id, blockedId: userA.id });
      await expect(service.getOrCreateConversation(userA.id, userB.id)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('should return existing conversation if one already exists without creating duplicate', async () => {
      const existingConv: Partial<Conversation> = {
        id: 'conv-existing',
        user1Id: userA.id,
        user2Id: userB.id,
        user1: userA,
        user2: userB,
        lastMessageAt: new Date(),
        participants: [
          { id: 'p1', conversationId: 'conv-existing', userId: userA.id } as ConversationParticipant,
          { id: 'p2', conversationId: 'conv-existing', userId: userB.id } as ConversationParticipant,
        ],
      };
      mockConversationRepo.findOne.mockResolvedValueOnce(existingConv);

      const result = await service.getOrCreateConversation(userA.id, userB.id);
      expect(result.id).toBe('conv-existing');
      expect(mockDataSource.createQueryRunner).not.toHaveBeenCalled();
      expect(result.participant.id).toBe(userB.id);
    });

    it('should create new conversation in a transaction when none exists', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(null);

      const result = await service.getOrCreateConversation(userA.id, userB.id);
      expect(result.id).toBe('conv-123');
      expect(mockDataSource.createQueryRunner).toHaveBeenCalled();
    });
  });

  describe('sendMessage', () => {
    const conv: Partial<Conversation> = {
      id: 'conv-123',
      user1Id: userA.id,
      user2Id: userB.id,
      lastMessageAt: new Date(),
    };

    it('should reject non-participant with ForbiddenException', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(conv);
      await expect(
        service.sendMessage('conv-123', 'intruder-id', {
          clientMessageId: 'c1',
          content: 'Hello',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should reject if blocked with ForbiddenException', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(conv);
      mockBlockRepo.findOne.mockResolvedValueOnce({ id: 'block-1' });

      await expect(
        service.sendMessage('conv-123', userA.id, {
          clientMessageId: 'c1',
          content: 'Hello',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should enforce idempotency and return existing message for duplicate clientMessageId', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(conv);
      const existingMsg: Partial<Message> = {
        id: 'msg-existing',
        senderId: userA.id,
        clientMessageId: 'c1',
        content: 'Original message',
        conversationId: 'conv-123',
      };
      mockMessageRepo.findOne.mockResolvedValueOnce(existingMsg);

      const result = await service.sendMessage('conv-123', userA.id, {
        clientMessageId: 'c1',
        content: 'Original message retry',
      });

      expect(result.message.id).toBe('msg-existing');
      expect(mockMessageRepo.create).not.toHaveBeenCalled();
    });

    it('should persist new message, update lastMessageAt, and return message', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(conv);
      mockMessageRepo.findOne.mockResolvedValueOnce(null);

      const result = await service.sendMessage('conv-123', userA.id, {
        clientMessageId: 'client-uuid-1',
        content: 'Hello neighbor!',
      });

      expect(result.message.content).toBe('Hello neighbor!');
      expect(result.recipientId).toBe(userB.id);
      expect(mockConversationRepo.update).toHaveBeenCalledWith('conv-123', expect.any(Object));
    });

    it('should reject empty or whitespace message with BadRequestException', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(conv);
      mockMessageRepo.findOne.mockResolvedValueOnce(null);

      await expect(
        service.sendMessage('conv-123', userA.id, {
          clientMessageId: 'c1',
          content: '    ',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should enforce rate limiting with 429 when threshold exceeded', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(conv);
      mockMessageRepo.findOne.mockResolvedValueOnce(null);
      mockRedisService.incr.mockResolvedValueOnce(31); // Exceeds 30/min

      await expect(
        service.sendMessage('conv-123', userA.id, {
          clientMessageId: 'c-rate',
          content: 'Spam text',
        }),
      ).rejects.toThrow(HttpException);
    });

    it('should persist image message with media metadata and return message', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(conv);
      mockMessageRepo.findOne.mockResolvedValueOnce(null);

      const result = await service.sendMessage('conv-123', userA.id, {
        clientMessageId: 'c-img-1',
        content: 'Check out this photo',
        messageType: MessageType.IMAGE,
        mediaUrl: 'http://localhost:3000/api/v1/media/files/img_123.webp',
        mediaThumbnailUrl: 'http://localhost:3000/api/v1/media/files/thumb_123.webp',
        mediaWidth: 1200,
        mediaHeight: 800,
        mediaSize: 154000,
        mediaMimeType: 'image/webp',
      });

      expect(result.message.messageType).toBe(MessageType.IMAGE);
      expect(result.message.mediaUrl).toBe('http://localhost:3000/api/v1/media/files/img_123.webp');
      expect(result.message.mediaThumbnailUrl).toBe('http://localhost:3000/api/v1/media/files/thumb_123.webp');
      expect(result.message.content).toBe('Check out this photo');
      expect(mockMessageRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          messageType: MessageType.IMAGE,
          mediaUrl: 'http://localhost:3000/api/v1/media/files/img_123.webp',
          mediaWidth: 1200,
        }),
      );
    });

    it('should default content to Photo when sending image without text caption', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(conv);
      mockMessageRepo.findOne.mockResolvedValueOnce(null);

      const result = await service.sendMessage('conv-123', userA.id, {
        clientMessageId: 'c-img-2',
        messageType: MessageType.IMAGE,
        mediaUrl: 'http://localhost:3000/api/v1/media/files/img_nocap.webp',
      });

      expect(result.message.messageType).toBe(MessageType.IMAGE);
      expect(result.message.content).toBe('Photo');
    });

    it('should reject image message when mediaUrl is missing', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce(conv);
      mockMessageRepo.findOne.mockResolvedValueOnce(null);

      await expect(
        service.sendMessage('conv-123', userA.id, {
          clientMessageId: 'c-img-err',
          messageType: MessageType.IMAGE,
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('markAsRead', () => {
    it('should update participant lastReadAt and messages readAt', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce({
        id: 'conv-123',
        user1Id: userA.id,
        user2Id: userB.id,
      });

      const result = await service.markAsRead('conv-123', userA.id);
      expect(result.unreadCount).toBe(0);
      expect(result.readAt).toBeInstanceOf(Date);
      expect(mockParticipantRepo.update).toHaveBeenCalled();
    });
  });

  describe('deleteMessage', () => {
    it('should soft delete own message', async () => {
      mockMessageRepo.findOne.mockResolvedValueOnce({
        id: 'msg-1',
        senderId: userA.id,
        content: 'My secret',
      });

      const result = await service.deleteMessage('msg-1', userA.id);
      expect(result.status).toBe('deleted');
      expect(mockMessageRepo.save).toHaveBeenCalled();
    });

    it('should reject deleting another user message with ForbiddenException', async () => {
      mockMessageRepo.findOne.mockResolvedValueOnce({
        id: 'msg-1',
        senderId: userB.id,
        content: 'User B message',
      });

      await expect(service.deleteMessage('msg-1', userA.id)).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('blocking and reporting', () => {
    it('should block a user', async () => {
      mockBlockRepo.findOne.mockResolvedValueOnce(null);
      const res = await service.blockUser(userA.id, userB.id);
      expect(res.success).toBe(true);
      expect(mockBlockRepo.save).toHaveBeenCalled();
    });

    it('should reject blocking self', async () => {
      await expect(service.blockUser(userA.id, userA.id)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should unblock a user', async () => {
      const res = await service.unblockUser(userA.id, userB.id);
      expect(res.success).toBe(true);
      expect(mockBlockRepo.delete).toHaveBeenCalled();
    });

    it('should submit a report for a conversation', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce({
        id: 'conv-123',
        user1Id: userA.id,
        user2Id: userB.id,
      });
      mockReportRepo.findOne.mockResolvedValueOnce(null);

      const res = await service.reportConversation(userA.id, 'conv-123', {
        reason: ConversationReportReason.HARASSMENT,
        description: 'Unacceptable behavior',
      });

      expect(res.message).toContain('Report submitted successfully');
      expect(mockReportRepo.save).toHaveBeenCalled();
    });

    it('should reject duplicate pending report with ConflictException', async () => {
      mockConversationRepo.findOne.mockResolvedValueOnce({
        id: 'conv-123',
        user1Id: userA.id,
        user2Id: userB.id,
      });
      mockReportRepo.findOne.mockResolvedValueOnce({ id: 'rep-dup' });

      await expect(
        service.reportConversation(userA.id, 'conv-123', {
          reason: ConversationReportReason.SPAM,
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('presence and typing', () => {
    it('should set and check presence in Redis', async () => {
      await service.setPresence(userA.id, true);
      expect(mockRedisService.set).toHaveBeenCalledWith(`presence:${userA.id}`, 'online', 180);

      mockRedisService.get.mockResolvedValueOnce('online');
      const isOnline = await service.isUserOnline(userA.id);
      expect(isOnline).toBe(true);
    });

    it('should throttle typing indicators', async () => {
      mockRedisService.exists.mockResolvedValueOnce(false);
      const first = await service.shouldEmitTyping(userA.id, 'conv-123');
      expect(first).toBe(true);

      mockRedisService.exists.mockResolvedValueOnce(true);
      const second = await service.shouldEmitTyping(userA.id, 'conv-123');
      expect(second).toBe(false);
    });
  });
});

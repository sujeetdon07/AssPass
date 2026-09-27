import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  HttpException,
} from '@nestjs/common';
import { SafetyService } from '../../src/modules/safety/safety.service.js';
import { SafetyReportTargetType, SafetyReportReason } from '../../src/modules/safety/dto/create-safety-report.dto.js';
import { SafetyModerationStatus } from '../../src/modules/safety/entities/safety-report.entity.js';
import { UserStatus } from '../../src/modules/users/entities/user.entity.js';

describe('SafetyService', () => {
  let service: SafetyService;
  let mockBlockRepo: any;
  let mockUserRepo: any;
  let mockReportRepo: any;
  let mockMarketplaceReportRepo: any;
  let mockBusinessReportRepo: any;
  let mockServiceReportRepo: any;
  let mockSafetyReportRepo: any;
  let mockAuditLogRepo: any;
  let mockPostRepo: any;
  let mockCommentRepo: any;
  let mockMarketplaceListingRepo: any;
  let mockBusinessRepo: any;
  let mockServiceListingRepo: any;
  let mockConversationRepo: any;
  let mockMessageRepo: any;
  let mockConversationReportRepo: any;
  let mockEventRepo: any;
  let mockRedisService: any;

  const mockUser1 = {
    id: '11111111-1111-1111-1111-111111111111',
    displayName: 'User One',
    accountStatus: UserStatus.ACTIVE,
  };

  const mockUser2 = {
    id: '22222222-2222-2222-2222-222222222222',
    displayName: 'User Two',
    avatarUrl: 'https://example.com/avatar.jpg',
    accountStatus: UserStatus.ACTIVE,
    locality: 'Indiranagar',
    city: 'Bengaluru',
  };

  beforeEach(() => {
    mockBlockRepo = {
      findOne: vi.fn().mockResolvedValue(null),
      save: vi.fn().mockResolvedValue({ id: 'block-1', createdAt: new Date() }),
      create: vi.fn((data: any) => ({ ...data, id: 'block-1', createdAt: new Date() })),
      delete: vi.fn().mockResolvedValue({ affected: 1 }),
      createQueryBuilder: vi.fn(),
    };

    mockUserRepo = {
      findOne: vi.fn().mockResolvedValue(mockUser2),
      find: vi.fn(),
    };

    mockReportRepo = {
      findOne: vi.fn().mockResolvedValue(null),
      save: vi.fn().mockResolvedValue({ id: 'rep-1' }),
      create: vi.fn((data: any) => ({ ...data, id: 'rep-1', createdAt: new Date() })),
    };

    mockMarketplaceReportRepo = {
      findOne: vi.fn().mockResolvedValue(null),
      save: vi.fn().mockResolvedValue({ id: 'mrep-1' }),
      create: vi.fn((data: any) => ({ ...data, id: 'mrep-1', createdAt: new Date() })),
    };

    mockBusinessReportRepo = {
      findOne: vi.fn().mockResolvedValue(null),
      save: vi.fn().mockResolvedValue({ id: 'brep-1' }),
      create: vi.fn((data: any) => ({ ...data, id: 'brep-1', createdAt: new Date() })),
    };

    mockServiceReportRepo = {
      findOne: vi.fn().mockResolvedValue(null),
      save: vi.fn().mockResolvedValue({ id: 'srep-1' }),
      create: vi.fn((data: any) => ({ ...data, id: 'srep-1', createdAt: new Date() })),
    };

    mockSafetyReportRepo = {
      findOne: vi.fn().mockResolvedValue(null),
      save: vi.fn().mockImplementation((r: any) => Promise.resolve({ ...r, id: r.id || 'sr-123', createdAt: new Date() })),
      create: vi.fn((data: any) => ({ ...data, id: 'sr-123', createdAt: new Date() })),
      createQueryBuilder: vi.fn(),
    };

    mockAuditLogRepo = {
      save: vi.fn().mockResolvedValue({ id: 'audit-1' }),
      create: vi.fn((data: any) => ({ ...data, id: 'audit-1', createdAt: new Date() })),
      createQueryBuilder: vi.fn(),
    };

    mockPostRepo = {
      findOne: vi.fn().mockResolvedValue({ id: 'post-1' }),
    };

    mockCommentRepo = {
      findOne: vi.fn().mockResolvedValue({ id: 'comment-1' }),
    };

    mockMarketplaceListingRepo = {
      findOne: vi.fn().mockResolvedValue({ id: 'listing-1' }),
    };

    mockBusinessRepo = {
      findOne: vi.fn().mockResolvedValue({ id: 'biz-1' }),
    };

    mockServiceListingRepo = {
      findOne: vi.fn().mockResolvedValue({ id: 'svc-1' }),
    };

    mockConversationRepo = {
      findOne: vi.fn().mockResolvedValue({
        id: 'conv-1',
        user1Id: mockUser1.id,
        user2Id: mockUser2.id,
      }),
    };

    mockMessageRepo = {
      findOne: vi.fn().mockResolvedValue({
        id: 'msg-1',
        conversationId: 'conv-1',
      }),
    };

    mockConversationReportRepo = {
      findOne: vi.fn().mockResolvedValue(null),
      save: vi.fn().mockResolvedValue({ id: 'crep-1' }),
      create: vi.fn((data: any) => ({ ...data, id: 'crep-1', createdAt: new Date() })),
    };

    mockEventRepo = {
      findOne: vi.fn().mockResolvedValue({ id: 'event-1', creatorId: mockUser2.id }),
    };

    mockRedisService = {
      get: vi.fn().mockResolvedValue(null),
      incr: vi.fn().mockResolvedValue(1),
      expire: vi.fn().mockResolvedValue(1),
      del: vi.fn().mockResolvedValue(1),
    };

    service = new SafetyService(
      mockSafetyReportRepo,
      mockAuditLogRepo,
      mockBlockRepo,
      mockUserRepo,
      mockReportRepo,
      mockPostRepo,
      mockCommentRepo,
      mockMarketplaceReportRepo,
      mockMarketplaceListingRepo,
      mockBusinessReportRepo,
      mockBusinessRepo,
      mockServiceReportRepo,
      mockServiceListingRepo,
      mockConversationRepo,
      mockMessageRepo,
      mockConversationReportRepo,
      mockEventRepo,
      mockRedisService,
    );
  });

  describe('blockUser', () => {
    it('throws BadRequestException when user tries to block themselves', async () => {
      await expect(service.blockUser(mockUser1.id, mockUser1.id)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('throws NotFoundException if target user does not exist', async () => {
      mockUserRepo.findOne.mockResolvedValue(null);
      await expect(service.blockUser(mockUser1.id, mockUser2.id)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('returns success idempotently if already blocked', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockUser2);
      mockBlockRepo.findOne.mockResolvedValue({
        id: 'existing-block-id',
        blockerId: mockUser1.id,
        blockedId: mockUser2.id,
      });

      const result = await service.blockUser(mockUser1.id, mockUser2.id);
      expect(result.success).toBe(true);
      expect(result.message).toContain('blocked');
      expect(mockBlockRepo.save).not.toHaveBeenCalled();
    });

    it('creates and saves new block when valid', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockUser2);
      mockBlockRepo.findOne.mockResolvedValue(null);
      mockBlockRepo.save.mockResolvedValue({
        id: 'new-block-id',
        blockerId: mockUser1.id,
        blockedId: mockUser2.id,
      });

      const result = await service.blockUser(mockUser1.id, mockUser2.id);
      expect(result.success).toBe(true);
      expect(result.message).toContain('blocked');
      expect(mockBlockRepo.save).toHaveBeenCalled();
    });
  });

  describe('unblockUser', () => {
    it('unblocks user cleanly', async () => {
      mockBlockRepo.delete.mockResolvedValue({ affected: 1 });
      const result = await service.unblockUser(mockUser1.id, mockUser2.id);
      expect(result.success).toBe(true);
      expect(result.message).toContain('unblocked');
      expect(mockBlockRepo.delete).toHaveBeenCalledWith({
        blockerId: mockUser1.id,
        blockedId: mockUser2.id,
      });
    });

    it('throws BadRequestException if unblocking oneself', async () => {
      await expect(service.unblockUser(mockUser1.id, mockUser1.id)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('getBlockedUsers', () => {
    it('returns empty list when no users are blocked', async () => {
      const qbMock: any = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([]),
      };
      mockBlockRepo.createQueryBuilder.mockReturnValue(qbMock);

      const result = await service.getBlockedUsers(mockUser1.id, 20);
      expect(result.items).toHaveLength(0);
      expect(result.hasMore).toBe(false);
      expect(result.nextCursor).toBeNull();
    });

    it('returns sanitized public profiles without phone or PII', async () => {
      const createdAt = new Date('2026-09-25T10:00:00.000Z');
      const qbMock: any = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([
          {
            id: 'blk-1',
            blockerId: mockUser1.id,
            blockedId: mockUser2.id,
            blocked: mockUser2,
            createdAt,
          },
        ]),
      };
      mockBlockRepo.createQueryBuilder.mockReturnValue(qbMock);

      const result = await service.getBlockedUsers(mockUser1.id, 20);
      expect(result.items).toHaveLength(1);
      const item = result.items[0];
      expect(item.blockId).toBe('blk-1');
      expect(item.blockedUser.id).toBe(mockUser2.id);
      expect(item.blockedUser.displayName).toBe(mockUser2.displayName);
      expect(item.blockedUser.avatarUrl).toBe(mockUser2.avatarUrl);
      expect(item.blockedUser.locality).toBe(mockUser2.locality);
      expect(item.blockedUser.city).toBe(mockUser2.city);
      expect((item.blockedUser as any).phoneNumber).toBeUndefined();
    });
  });

  describe('submitReport', () => {
    it('rejects with 429 when rate limit is exceeded', async () => {
      mockRedisService.get.mockResolvedValue('10');
      await expect(
        service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.POST,
          targetId: 'post-1',
          reason: SafetyReportReason.SPAM,
        }),
      ).rejects.toThrow(HttpException);
    });

    describe('USER reporting', () => {
      it('rejects self-reporting with BadRequestException', async () => {
        await expect(
          service.submitReport(mockUser1.id, {
            targetType: SafetyReportTargetType.USER,
            targetId: mockUser1.id,
            reason: SafetyReportReason.HARASSMENT,
          }),
        ).rejects.toThrow(BadRequestException);
      });

      it('rejects reporting non-existent user with NotFoundException', async () => {
        mockUserRepo.findOne.mockResolvedValue(null);
        await expect(
          service.submitReport(mockUser1.id, {
            targetType: SafetyReportTargetType.USER,
            targetId: mockUser2.id,
            reason: SafetyReportReason.HARASSMENT,
          }),
        ).rejects.toThrow(NotFoundException);
      });

      it('rejects duplicate active report with ConflictException (409)', async () => {
        mockSafetyReportRepo.findOne.mockResolvedValue({
          id: 'sr-existing',
          status: SafetyModerationStatus.PENDING,
        });

        await expect(
          service.submitReport(mockUser1.id, {
            targetType: SafetyReportTargetType.USER,
            targetId: mockUser2.id,
            reason: SafetyReportReason.HARASSMENT,
          }),
        ).rejects.toThrow(ConflictException);
      });

      it('submits a user report successfully and logs audit event', async () => {
        const result = await service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.USER,
          targetId: mockUser2.id,
          reason: SafetyReportReason.HARASSMENT,
          details: 'Harassing messages in thread',
        });

        expect(result.success).toBe(true);
        expect(result.message).toContain('Thank you');
        expect(mockSafetyReportRepo.save).toHaveBeenCalled();
        expect(mockAuditLogRepo.save).toHaveBeenCalled();
      });
    });

    describe('Content reporting', () => {
      it('submits a post report successfully', async () => {
        const result = await service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.POST,
          targetId: 'post-1',
          reason: SafetyReportReason.HARASSMENT,
          details: 'Offensive language',
        });

        expect(result.success).toBe(true);
        expect(mockReportRepo.save).toHaveBeenCalled();
        expect(mockSafetyReportRepo.save).toHaveBeenCalled();
      });

      it('submits a comment report successfully', async () => {
        const result = await service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.COMMENT,
          targetId: 'comment-1',
          reason: SafetyReportReason.HATE_OR_ABUSE,
        });

        expect(result.success).toBe(true);
        expect(mockReportRepo.save).toHaveBeenCalled();
      });

      it('submits a marketplace report with mapped reason', async () => {
        const result = await service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.LISTING,
          targetId: 'listing-1',
          reason: SafetyReportReason.SCAM_OR_FRAUD,
          details: 'Fake seller',
        });

        expect(result.success).toBe(true);
        expect(mockMarketplaceReportRepo.save).toHaveBeenCalled();
      });

      it('submits a business report successfully', async () => {
        const result = await service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.BUSINESS,
          targetId: 'biz-1',
          reason: SafetyReportReason.MISINFORMATION,
        });

        expect(result.success).toBe(true);
        expect(mockBusinessReportRepo.save).toHaveBeenCalled();
      });

      it('submits a service report successfully', async () => {
        const result = await service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.SERVICE,
          targetId: 'svc-1',
          reason: SafetyReportReason.INAPPROPRIATE_CONTENT,
        });

        expect(result.success).toBe(true);
        expect(mockServiceReportRepo.save).toHaveBeenCalled();
      });

      it('throws NotFoundException if target post does not exist', async () => {
        mockPostRepo.findOne.mockResolvedValue(null);
        await expect(
          service.submitReport(mockUser1.id, {
            targetType: SafetyReportTargetType.POST,
            targetId: 'missing-post',
            reason: SafetyReportReason.SPAM,
          }),
        ).rejects.toThrow(NotFoundException);
      });
    });

    describe('Messaging reporting', () => {
      it('submits conversation report when caller is a participant', async () => {
        const result = await service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.CONVERSATION,
          targetId: 'conv-1',
          reason: SafetyReportReason.THREATS,
        });

        expect(result.success).toBe(true);
        expect(mockConversationReportRepo.save).toHaveBeenCalled();
        expect(mockSafetyReportRepo.save).toHaveBeenCalled();
      });

      it('rejects conversation report when caller is NOT a participant (ForbiddenException)', async () => {
        const outsiderId = '33333333-3333-3333-3333-333333333333';
        await expect(
          service.submitReport(outsiderId, {
            targetType: SafetyReportTargetType.CONVERSATION,
            targetId: 'conv-1',
            reason: SafetyReportReason.THREATS,
          }),
        ).rejects.toThrow(ForbiddenException);
      });

      it('submits message report with conversation verification', async () => {
        const result = await service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.MESSAGE,
          targetId: 'msg-1',
          reason: SafetyReportReason.HARASSMENT,
        });

        expect(result.success).toBe(true);
        expect(mockSafetyReportRepo.save).toHaveBeenCalled();
      });
    });

    describe('Event reporting', () => {
      it('submits an event report successfully', async () => {
        const result = await service.submitReport(mockUser1.id, {
          targetType: SafetyReportTargetType.EVENT,
          targetId: 'event-1',
          reason: SafetyReportReason.SPAM,
          details: 'Commercial spam event',
        });

        expect(result.success).toBe(true);
        expect(mockSafetyReportRepo.save).toHaveBeenCalled();
        expect(mockAuditLogRepo.save).toHaveBeenCalled();
      });

      it('throws NotFoundException if target event does not exist', async () => {
        mockEventRepo.findOne.mockResolvedValue(null);

        await expect(
          service.submitReport(mockUser1.id, {
            targetType: SafetyReportTargetType.EVENT,
            targetId: 'non-existent',
            reason: SafetyReportReason.SPAM,
          }),
        ).rejects.toThrow(NotFoundException);
      });

      it('throws BadRequestException if organizer tries to report their own event', async () => {
        mockEventRepo.findOne.mockResolvedValue({ id: 'event-1', creatorId: mockUser1.id });

        await expect(
          service.submitReport(mockUser1.id, {
            targetType: SafetyReportTargetType.EVENT,
            targetId: 'event-1',
            reason: SafetyReportReason.SPAM,
          }),
        ).rejects.toThrow(BadRequestException);
      });
    });
  });

  describe('getMyReports', () => {
    it('returns only reports created by authenticated user without internal notes', async () => {
      const createdAt = new Date('2026-09-25T11:00:00.000Z');
      const qbMock: any = {
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([
          {
            id: 'sr-1',
            reporterId: mockUser1.id,
            targetType: SafetyReportTargetType.USER,
            targetId: mockUser2.id,
            reason: SafetyReportReason.HARASSMENT,
            status: SafetyModerationStatus.REVIEWING,
            details: 'Harassing me in DM',
            moderationNotes: 'INTERNAL CONFIDENTIAL NOTE',
            reviewedBy: 'admin-123',
            createdAt,
          },
        ]),
      };
      mockSafetyReportRepo.createQueryBuilder.mockReturnValue(qbMock);

      const result = await service.getMyReports(mockUser1.id, 20);

      expect(result.items).toHaveLength(1);
      const item = result.items[0];
      expect(item.id).toBe('sr-1');
      expect(item.targetType).toBe(SafetyReportTargetType.USER);
      expect(item.targetId).toBe(mockUser2.id);
      expect(item.reason).toBe(SafetyReportReason.HARASSMENT);
      expect(item.status).toBe(SafetyModerationStatus.REVIEWING);
      expect(item.details).toBe('Harassing me in DM');
      expect((item as any).moderationNotes).toBeUndefined();
      expect((item as any).reviewedBy).toBeUndefined();
    });
  });

  describe('updateReportStatus', () => {
    it('updates report status and creates audit log', async () => {
      mockSafetyReportRepo.findOne.mockResolvedValue({
        id: 'sr-1',
        status: SafetyModerationStatus.PENDING,
        targetType: SafetyReportTargetType.USER,
        targetId: mockUser2.id,
      });

      const updated = await service.updateReportStatus(
        'sr-1',
        SafetyModerationStatus.ACTIONED,
        'mod-1',
        'User violated guidelines',
      );

      expect(updated.success).toBe(true);
      expect(updated.report.status).toBe(SafetyModerationStatus.ACTIONED);
      expect(mockSafetyReportRepo.save).toHaveBeenCalled();
      expect(mockAuditLogRepo.save).toHaveBeenCalled();
    });

    it('throws NotFoundException if report does not exist', async () => {
      mockSafetyReportRepo.findOne.mockResolvedValue(null);
      await expect(
        service.updateReportStatus('missing-rep', SafetyModerationStatus.ACTIONED, 'mod-1'),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('assertNotBlocked', () => {
    it('throws ForbiddenException when block exists', async () => {
      mockBlockRepo.findOne.mockResolvedValue({ id: 'blk-1' });
      await expect(
        service.assertNotBlocked(mockUser1.id, mockUser2.id),
      ).rejects.toThrow(ForbiddenException);
    });

    it('resolves silently when no block exists', async () => {
      mockBlockRepo.findOne.mockResolvedValue(null);
      await expect(
        service.assertNotBlocked(mockUser1.id, mockUser2.id),
      ).resolves.toBeUndefined();
    });
  });

  describe('isBlocked', () => {
    it('returns true if a block exists between users', async () => {
      mockBlockRepo.findOne.mockResolvedValue({ id: 'blk-1' });
      const blocked = await service.isBlocked(mockUser1.id, mockUser2.id);
      expect(blocked).toBe(true);
    });

    it('returns false if no block exists', async () => {
      mockBlockRepo.findOne.mockResolvedValue(null);
      const blocked = await service.isBlocked(mockUser1.id, mockUser2.id);
      expect(blocked).toBe(false);
    });
  });
});

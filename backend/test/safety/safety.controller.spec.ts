import { describe, it, expect, beforeEach, vi } from 'vitest';
import { SafetyController } from '../../src/modules/safety/safety.controller.js';
import { SafetyReportTargetType, SafetyReportReason } from '../../src/modules/safety/dto/create-safety-report.dto.js';
import { SafetyModerationStatus } from '../../src/modules/safety/entities/safety-report.entity.js';
import type { CurrentUserPayload } from '../../src/modules/auth/decorators/current-user.decorator.js';

describe('SafetyController', () => {
  let controller: SafetyController;
  let mockSafetyService: any;

  const mockUserPayload: CurrentUserPayload = {
    userId: '11111111-1111-1111-1111-111111111111',
    phoneNumber: '+919876543210',
    sessionId: 'sess-1',
    onboarding: true,
    role: 'user',
  };

  const mockModeratorPayload: CurrentUserPayload = {
    userId: 'mod-1111-1111-1111-111111111111',
    phoneNumber: '+919876543299',
    sessionId: 'sess-mod',
    onboarding: true,
    role: 'moderator',
  };

  const targetUserId = '22222222-2222-2222-2222-222222222222';

  beforeEach(() => {
    mockSafetyService = {
      blockUser: vi.fn().mockResolvedValue({ success: true, message: 'User blocked successfully.' }),
      unblockUser: vi.fn().mockResolvedValue({ success: true, message: 'User unblocked successfully.' }),
      getBlockedUsers: vi.fn().mockResolvedValue({ items: [], nextCursor: null, hasMore: false }),
      submitReport: vi.fn().mockResolvedValue({ success: true, message: 'Thank you for helping keep Aaspaas safe.' }),
      getMyReports: vi.fn().mockResolvedValue({ items: [], nextCursor: null, hasMore: false }),
      updateReportStatus: vi.fn().mockResolvedValue({ id: 'rep-1', status: SafetyModerationStatus.ACTIONED }),
      getAuditLogs: vi.fn().mockResolvedValue({ items: [], nextCursor: null, hasMore: false }),
    };

    controller = new SafetyController(mockSafetyService);
  });

  describe('blockUser', () => {
    it('delegates to safetyService.blockUser using authenticated user id', async () => {
      const res = await controller.blockUser(mockUserPayload, targetUserId);
      expect(mockSafetyService.blockUser).toHaveBeenCalledWith(mockUserPayload.userId, targetUserId);
      expect(res.success).toBe(true);
    });
  });

  describe('unblockUser', () => {
    it('delegates to safetyService.unblockUser using authenticated user id', async () => {
      const res = await controller.unblockUser(targetUserId, mockUserPayload);
      expect(mockSafetyService.unblockUser).toHaveBeenCalledWith(mockUserPayload.userId, targetUserId);
      expect(res.success).toBe(true);
    });
  });

  describe('getBlockedUsers', () => {
    it('delegates with parsed limit and cursor', async () => {
      await controller.getBlockedUsers(mockUserPayload, 15, 'cursor-abc');
      expect(mockSafetyService.getBlockedUsers).toHaveBeenCalledWith(
        mockUserPayload.userId,
        15,
        'cursor-abc',
      );
    });

    it('caps limit at 50 if higher limit requested', async () => {
      await controller.getBlockedUsers(mockUserPayload, 100);
      expect(mockSafetyService.getBlockedUsers).toHaveBeenCalledWith(
        mockUserPayload.userId,
        50,
        undefined,
      );
    });
  });

  describe('submitReport', () => {
    it('delegates to safetyService.submitReport', async () => {
      const dto = {
        targetType: SafetyReportTargetType.POST,
        targetId: '33333333-3333-3333-3333-333333333333',
        reason: SafetyReportReason.SPAM,
      };

      const res = await controller.submitReport(mockUserPayload, dto);
      expect(mockSafetyService.submitReport).toHaveBeenCalledWith(mockUserPayload.userId, dto);
      expect(res.message).toContain('Thank you');
    });
  });

  describe('getMyReports', () => {
    it('delegates to safetyService.getMyReports with caller userId', async () => {
      await controller.getMyReports(mockUserPayload, 20, 'cur-1');
      expect(mockSafetyService.getMyReports).toHaveBeenCalledWith(
        mockUserPayload.userId,
        20,
        'cur-1',
      );
    });

    it('caps limit at 50', async () => {
      await controller.getMyReports(mockUserPayload, 200);
      expect(mockSafetyService.getMyReports).toHaveBeenCalledWith(
        mockUserPayload.userId,
        50,
        undefined,
      );
    });
  });

  describe('updateReportStatus', () => {
    it('delegates to safetyService.updateReportStatus with moderator id', async () => {
      await controller.updateReportStatus(
        'rep-1',
        SafetyModerationStatus.ACTIONED,
        'Violated TOS',
        mockModeratorPayload,
      );
      expect(mockSafetyService.updateReportStatus).toHaveBeenCalledWith(
        'rep-1',
        SafetyModerationStatus.ACTIONED,
        mockModeratorPayload.userId,
        'Violated TOS',
      );
    });
  });

  describe('getAuditLogs', () => {
    it('delegates to safetyService.getAuditLogs with parsed limit and cursor', async () => {
      await controller.getAuditLogs(25, 'aud-cur');
      expect(mockSafetyService.getAuditLogs).toHaveBeenCalledWith(25, 'aud-cur');
    });
  });
});

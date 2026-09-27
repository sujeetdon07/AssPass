import { describe, it, expect, beforeEach, vi } from 'vitest';
import { NotFoundException, ConflictException } from '@nestjs/common';
import { ReportsService } from '../../src/modules/feed/services/reports.service.js';
import { ReportReason } from '../../src/modules/feed/entities/report.entity.js';

describe('ReportsService', () => {
  let service: ReportsService;
  let mockReportRepo: any;
  let mockPostRepo: any;
  let mockCommentRepo: any;
  let mockRedisService: any;

  beforeEach(() => {
    mockReportRepo = {
      findOne: vi.fn(),
      create: vi.fn((data: any) => ({ ...data, id: 'report-1' })),
      save: vi.fn(),
    };

    mockPostRepo = {
      findOne: vi.fn(),
    };

    mockCommentRepo = {
      findOne: vi.fn(),
    };

    mockRedisService = {
      get: vi.fn().mockResolvedValue(null),
      set: vi.fn().mockResolvedValue('OK'),
      ttl: vi.fn().mockResolvedValue(3600),
      incr: vi.fn().mockResolvedValue(1),
      expire: vi.fn().mockResolvedValue(1),
      del: vi.fn().mockResolvedValue(1),
    };

    service = new ReportsService(
      mockReportRepo,
      mockPostRepo,
      mockCommentRepo,
      mockRedisService,
    );
  });

  describe('reportPost', () => {
    it('creates a report when valid reason is provided', async () => {
      mockPostRepo.findOne.mockResolvedValue({ id: 'post-1' });
      mockReportRepo.findOne.mockResolvedValue(null); // not previously reported by this user

      const result = await service.reportPost('post-1', 'usr-reporter', {
        reason: ReportReason.SPAM,
        details: 'Promotional spam link',
      });

      expect(result.message).toContain('Your report has been submitted');
      expect(mockReportRepo.save).toHaveBeenCalled();
    });

    it('rejects duplicate reports from the same user with ConflictException', async () => {
      mockPostRepo.findOne.mockResolvedValue({ id: 'post-1' });
      mockReportRepo.findOne.mockResolvedValue({ id: 'existing-report' });

      await expect(
        service.reportPost('post-1', 'usr-reporter', {
          reason: ReportReason.SPAM,
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('throws NotFoundException if reported post does not exist', async () => {
      mockPostRepo.findOne.mockResolvedValue(null);

      await expect(
        service.reportPost('non-existent', 'usr-reporter', {
          reason: ReportReason.HARASSMENT,
        }),
      ).rejects.toThrow(NotFoundException);
    });
  });
});

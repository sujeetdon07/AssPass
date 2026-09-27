import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ExecutionContext, ForbiddenException, ValidationPipe, BadRequestException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from '../../src/modules/auth/guards/roles.guard.js';
import { UserRole } from '../../src/modules/users/entities/user.entity.js';
import {
  CreateSafetyReportDto,
  SafetyReportTargetType,
  SafetyReportReason,
} from '../../src/modules/safety/dto/create-safety-report.dto.js';
import { toPublicProfile } from '../../src/modules/messaging/serializers/public-profile.serializer.js';

describe('Trust & Safety Security & Hardening Tests', () => {
  const validUuid = 'c6a992a7-5192-4f3b-8bd2-55db6c6508da';

  describe('Authorization: RolesGuard', () => {
    let rolesGuard: RolesGuard;
    let reflector: Reflector;

    beforeEach(() => {
      reflector = new Reflector();
      rolesGuard = new RolesGuard(reflector);
    });

    it('allows access when no roles are required on route', () => {
      vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue(undefined);
      const context = {
        getHandler: vi.fn(),
        getClass: vi.fn(),
        switchToHttp: () => ({
          getRequest: () => ({ user: { role: UserRole.USER } }),
        }),
      } as unknown as ExecutionContext;

      expect(rolesGuard.canActivate(context)).toBe(true);
    });

    it('rejects unauthenticated user when roles are required', () => {
      vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue([UserRole.MODERATOR, UserRole.ADMIN]);
      const context = {
        getHandler: vi.fn(),
        getClass: vi.fn(),
        switchToHttp: () => ({
          getRequest: () => ({ user: null }),
        }),
      } as unknown as ExecutionContext;

      expect(() => rolesGuard.canActivate(context)).toThrow(ForbiddenException);
    });

    it('rejects ordinary USER from accessing MODERATOR/ADMIN endpoints', () => {
      vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue([UserRole.MODERATOR, UserRole.ADMIN]);
      const context = {
        getHandler: vi.fn(),
        getClass: vi.fn(),
        switchToHttp: () => ({
          getRequest: () => ({ user: { userId: 'usr-1', role: UserRole.USER } }),
        }),
      } as unknown as ExecutionContext;

      expect(() => rolesGuard.canActivate(context)).toThrow(ForbiddenException);
    });

    it('permits MODERATOR to access moderated endpoints', () => {
      vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue([UserRole.MODERATOR, UserRole.ADMIN]);
      const context = {
        getHandler: vi.fn(),
        getClass: vi.fn(),
        switchToHttp: () => ({
          getRequest: () => ({ user: { userId: 'mod-1', role: UserRole.MODERATOR } }),
        }),
      } as unknown as ExecutionContext;

      expect(rolesGuard.canActivate(context)).toBe(true);
    });

    it('permits ADMIN to access moderated endpoints', () => {
      vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue([UserRole.MODERATOR, UserRole.ADMIN]);
      const context = {
        getHandler: vi.fn(),
        getClass: vi.fn(),
        switchToHttp: () => ({
          getRequest: () => ({ user: { userId: 'admin-1', role: UserRole.ADMIN } }),
        }),
      } as unknown as ExecutionContext;

      expect(rolesGuard.canActivate(context)).toBe(true);
    });
  });

  describe('Mass Assignment & DTO Sanitization', () => {
    const pipe = new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    });

    it('validates a correct CreateSafetyReportDto', async () => {
      const payload = {
        targetType: SafetyReportTargetType.USER,
        targetId: validUuid,
        reason: SafetyReportReason.HARASSMENT,
        details: 'User sent abusive messages',
      };

      const result = await pipe.transform(payload, {
        type: 'body',
        metatype: CreateSafetyReportDto,
      });

      expect(result).toBeDefined();
      expect(result.targetType).toBe(SafetyReportTargetType.USER);
      expect(result.targetId).toBe(validUuid);
    });

    it('rejects invalid target type', async () => {
      const payload = {
        targetType: 'INVALID_TARGET',
        targetId: validUuid,
        reason: SafetyReportReason.SPAM,
      };

      await expect(
        pipe.transform(payload, { type: 'body', metatype: CreateSafetyReportDto }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects invalid report reason', async () => {
      const payload = {
        targetType: SafetyReportTargetType.POST,
        targetId: validUuid,
        reason: 'NOT_A_VALID_REASON',
      };

      await expect(
        pipe.transform(payload, { type: 'body', metatype: CreateSafetyReportDto }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects details exceeding 2000 characters', async () => {
      const payload = {
        targetType: SafetyReportTargetType.POST,
        targetId: validUuid,
        reason: SafetyReportReason.SPAM,
        details: 'A'.repeat(2001),
      };

      await expect(
        pipe.transform(payload, { type: 'body', metatype: CreateSafetyReportDto }),
      ).rejects.toThrow(BadRequestException);
    });

    it('accepts details within 2000 characters', async () => {
      const payload = {
        targetType: SafetyReportTargetType.POST,
        targetId: validUuid,
        reason: SafetyReportReason.SPAM,
        details: 'A'.repeat(2000),
      };

      const result = await pipe.transform(payload, {
        type: 'body',
        metatype: CreateSafetyReportDto,
      });
      expect(result.details).toHaveLength(2000);
    });

    it('rejects client-supplied mass-assignment fields on DTO (forbidNonWhitelisted)', async () => {
      const maliciousPayload = {
        targetType: SafetyReportTargetType.POST,
        targetId: validUuid,
        reason: SafetyReportReason.SPAM,
        reporterId: 'attacker-uuid',
        actorId: 'admin-uuid',
        status: 'actioned',
        role: 'admin',
        createdAt: '2020-01-01',
      };

      await expect(
        pipe.transform(maliciousPayload, {
          type: 'body',
          metatype: CreateSafetyReportDto,
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Privacy & PII Leak Prevention', () => {
    it('toPublicProfile strips phone number, email, and sensitive fields', () => {
      const rawUser = {
        id: 'user-secret-1',
        displayName: 'Aarav Sharma',
        avatarUrl: 'https://example.com/aarav.jpg',
        phoneNumber: '+919999988888',
        email: 'aarav@secret.com',
        fcmToken: 'fcm-device-token-secret-12345',
        refreshToken: 'jwt-refresh-token-secret',
        coordinates: { lat: 12.9716, lng: 77.5946 },
        locality: 'Indiranagar',
        city: 'Bengaluru',
      };

      const profile = toPublicProfile(rawUser);

      expect(profile.id).toBe('user-secret-1');
      expect(profile.displayName).toBe('Aarav Sharma');
      expect(profile.avatarUrl).toBe('https://example.com/aarav.jpg');
      expect(profile.locality).toBe('Indiranagar');
      expect(profile.city).toBe('Bengaluru');

      // CRITICAL: PII must never be present
      expect((profile as any).phoneNumber).toBeUndefined();
      expect((profile as any).email).toBeUndefined();
      expect((profile as any).fcmToken).toBeUndefined();
      expect((profile as any).refreshToken).toBeUndefined();
      expect((profile as any).coordinates).toBeUndefined();
    });
  });
});

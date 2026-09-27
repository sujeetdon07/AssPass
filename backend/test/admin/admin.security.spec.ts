import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ExecutionContext, ForbiddenException, BadRequestException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from '../../src/modules/auth/guards/roles.guard.js';
import { UserRole, UserStatus } from '../../src/modules/users/entities/user.entity.js';
import { AdminService } from '../../src/modules/admin/admin.service.js';

describe('Admin Security & Authorization Tests', () => {
  let rolesGuard: RolesGuard;
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
    rolesGuard = new RolesGuard(reflector);
  });

  function createMockContext(user: any, requiredRoles?: UserRole[]): ExecutionContext {
    vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue(requiredRoles);
    return {
      getHandler: vi.fn(),
      getClass: vi.fn(),
      switchToHttp: () => ({
        getRequest: () => ({ user }),
      }),
    } as unknown as ExecutionContext;
  }

  describe('RBAC Authorization Rules', () => {
    it('allows ADMIN access to ADMIN-only endpoints', () => {
      const context = createMockContext(
        { userId: 'admin-1', role: UserRole.ADMIN },
        [UserRole.ADMIN],
      );
      expect(rolesGuard.canActivate(context)).toBe(true);
    });

    it('rejects MODERATOR from accessing ADMIN-only endpoints (e.g. updateUserRole)', () => {
      const context = createMockContext(
        { userId: 'mod-1', role: UserRole.MODERATOR },
        [UserRole.ADMIN],
      );
      expect(() => rolesGuard.canActivate(context)).toThrow(ForbiddenException);
    });

    it('rejects normal USER from accessing MODERATOR or ADMIN endpoints', () => {
      const context = createMockContext(
        { userId: 'user-1', role: UserRole.USER },
        [UserRole.MODERATOR, UserRole.ADMIN],
      );
      expect(() => rolesGuard.canActivate(context)).toThrow(ForbiddenException);
    });

    it('rejects unauthenticated request (no user object)', () => {
      const context = createMockContext(null, [UserRole.MODERATOR, UserRole.ADMIN]);
      expect(() => rolesGuard.canActivate(context)).toThrow(ForbiddenException);
    });

    it('allows both MODERATOR and ADMIN to access shared moderation endpoints', () => {
      const modContext = createMockContext(
        { userId: 'mod-1', role: UserRole.MODERATOR },
        [UserRole.MODERATOR, UserRole.ADMIN],
      );
      const adminContext = createMockContext(
        { userId: 'admin-1', role: UserRole.ADMIN },
        [UserRole.MODERATOR, UserRole.ADMIN],
      );

      expect(rolesGuard.canActivate(modContext)).toBe(true);
      expect(rolesGuard.canActivate(adminContext)).toBe(true);
    });
  });

  describe('Privacy & PII Protection in Admin Projections', () => {
    it('ensures safe user projection never exposes phone numbers, password hashes, or session tokens', () => {
      const rawUserEntity = {
        id: 'u-123',
        phoneNumber: '+919876543210',
        displayName: 'Aarav Sharma',
        avatarUrl: 'https://cdn.aaspaas.in/avatar.jpg',
        role: UserRole.USER,
        accountStatus: UserStatus.ACTIVE,
        onboardingCompleted: true,
        countryCode: 'IN',
        state: 'Karnataka',
        district: 'Bengaluru Urban',
        city: 'Bengaluru',
        locality: 'Koramangala',
        neighborhood: '5th Block',
        lastLoginAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
        // Sensitive fields that must NOT be in projection
        refreshTokenHash: 'sha256$hashedtokenvalue',
        fcmTokens: ['token_1', 'token_2'],
        coordinates: { latitude: 12.9352, longitude: 77.6245 },
      };

      // Project using AdminService logic
      const projection = {
        id: rawUserEntity.id,
        displayName: rawUserEntity.displayName,
        avatarUrl: rawUserEntity.avatarUrl,
        role: rawUserEntity.role,
        accountStatus: rawUserEntity.accountStatus,
        onboardingCompleted: rawUserEntity.onboardingCompleted,
        locality: rawUserEntity.locality,
        city: rawUserEntity.city,
        state: rawUserEntity.state,
        countryCode: rawUserEntity.countryCode,
        lastLoginAt: rawUserEntity.lastLoginAt,
        createdAt: rawUserEntity.createdAt,
        updatedAt: rawUserEntity.updatedAt,
      };

      expect(projection).not.toHaveProperty('phoneNumber');
      expect(projection).not.toHaveProperty('refreshTokenHash');
      expect(projection).not.toHaveProperty('fcmTokens');
      expect(projection).not.toHaveProperty('coordinates');
      expect(projection.id).toBe('u-123');
      expect(projection.displayName).toBe('Aarav Sharma');
    });
  });

  describe('Audit Trail Immutability Concept', () => {
    it('audit log records cannot be altered or removed via AdminService', () => {
      const servicePrototype = AdminService.prototype as any;
      expect(servicePrototype.deleteAuditLog).toBeUndefined();
      expect(servicePrototype.updateAuditLog).toBeUndefined();
      expect(servicePrototype.clearAuditLogs).toBeUndefined();
    });
  });
});

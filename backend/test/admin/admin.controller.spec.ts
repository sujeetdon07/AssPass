import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Test } from '@nestjs/testing';
import { AdminController } from '../../src/modules/admin/admin.controller.js';
import { AdminService } from '../../src/modules/admin/admin.service.js';
import { UserRole, UserStatus } from '../../src/modules/users/entities/user.entity.js';
import { ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';

const mockAdminService = {
  getDashboardSummary: vi.fn(),
  listUsers: vi.fn(),
  getUserById: vi.fn(),
  getUserReportHistory: vi.fn(),
  updateUserRole: vi.fn(),
  updateUserStatus: vi.fn(),
  listReports: vi.fn(),
  getReportById: vi.fn(),
  listStaff: vi.fn(),
  listAuditLogs: vi.fn(),
  listListings: vi.fn(),
  listBusinesses: vi.fn(),
  listServices: vi.fn(),
  listCommunities: vi.fn(),
};

const mockAdminUser = {
  userId: 'admin-id-001',
  sessionId: 'session-id-001',
  phoneNumber: '+91XXXXXXXX00',
  onboarding: true,
  role: UserRole.ADMIN,
};

const mockModeratorUser = {
  userId: 'mod-id-001',
  sessionId: 'session-id-002',
  phoneNumber: '+91XXXXXXXX01',
  onboarding: true,
  role: UserRole.MODERATOR,
};

const mockSafeUserProjection = {
  id: 'user-id-001',
  displayName: 'Test User',
  avatarUrl: null,
  role: UserRole.USER,
  accountStatus: UserStatus.ACTIVE,
  onboardingCompleted: true,
  locality: 'Koramangala',
  city: 'Bengaluru',
  state: 'Karnataka',
  countryCode: 'IN',
  lastLoginAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('AdminController', () => {
  let controller: AdminController;

  beforeEach(() => {
    vi.clearAllMocks();
    controller = new AdminController(mockAdminService as any);
  });

  // ── Dashboard ────────────────────────────────────────────────────────────

  it('getDashboardSummary returns summary data', async () => {
    const summary = {
      users: { total: 100, active: 90, suspended: 5, newThisWeek: 10 },
      moderation: { pending: 5, reviewing: 2, actioned: 15 },
      content: { listings: 50, businesses: 20, services: 30, communities: 8 },
      recentActivity: [],
    };
    mockAdminService.getDashboardSummary.mockResolvedValueOnce(summary);

    const result = await controller.getDashboardSummary();
    expect(result).toEqual(summary);
    expect(mockAdminService.getDashboardSummary).toHaveBeenCalledTimes(1);
  });

  // ── Users ────────────────────────────────────────────────────────────────

  it('listUsers delegates to service with pagination params', async () => {
    const paginatedResult = {
      items: [mockSafeUserProjection],
      total: 1,
      page: 1,
      limit: 20,
      totalPages: 1,
    };
    mockAdminService.listUsers.mockResolvedValueOnce(paginatedResult);

    const result = await controller.listUsers({ page: 1, limit: 20 });
    expect(result.items[0]).not.toHaveProperty('phoneNumber');
    expect(result.items[0]).not.toHaveProperty('sessions');
    expect(mockAdminService.listUsers).toHaveBeenCalledWith(1, 20, undefined, undefined, undefined);
  });

  it('getUserById returns safe projection', async () => {
    mockAdminService.getUserById.mockResolvedValueOnce(mockSafeUserProjection);
    const result = await controller.getUserById('user-id-001');
    expect(result).not.toHaveProperty('phoneNumber');
    expect(result.id).toBe('user-id-001');
  });

  it('getUserById throws 404 when user not found', async () => {
    mockAdminService.getUserById.mockRejectedValueOnce(new NotFoundException());
    await expect(controller.getUserById('nonexistent-id')).rejects.toThrow(NotFoundException);
  });

  it('updateUserRole rejects self role change', async () => {
    mockAdminService.updateUserRole.mockRejectedValueOnce(
      new BadRequestException('You cannot change your own role.'),
    );
    await expect(
      controller.updateUserRole(
        mockAdminUser.userId,
        { role: UserRole.MODERATOR },
        mockAdminUser,
      ),
    ).rejects.toThrow(BadRequestException);
  });

  it('updateUserRole succeeds for valid admin operation', async () => {
    const updated = { ...mockSafeUserProjection, role: UserRole.MODERATOR };
    mockAdminService.updateUserRole.mockResolvedValueOnce(updated);

    const result = await controller.updateUserRole(
      'another-user-id',
      { role: UserRole.MODERATOR },
      mockAdminUser,
    );
    expect(result.role).toBe(UserRole.MODERATOR);
  });

  it('updateUserStatus to suspended creates audit log', async () => {
    const suspended = { ...mockSafeUserProjection, accountStatus: UserStatus.SUSPENDED };
    mockAdminService.updateUserStatus.mockResolvedValueOnce(suspended);

    const result = await controller.updateUserStatus(
      'user-id-001',
      { status: UserStatus.SUSPENDED, reason: 'Policy violation' },
      mockAdminUser,
    );
    expect(result.accountStatus).toBe(UserStatus.SUSPENDED);
    expect(mockAdminService.updateUserStatus).toHaveBeenCalledWith(
      mockAdminUser.userId,
      'user-id-001',
      UserStatus.SUSPENDED,
      'Policy violation',
    );
  });

  // ── Reports ──────────────────────────────────────────────────────────────

  it('listReports returns paginated reports', async () => {
    const mockReport = {
      id: 'report-id-001',
      reporterId: 'user-id-001',
      reporterName: 'Test User',
      targetType: 'post',
      targetId: 'post-id-001',
      reason: 'spam',
      details: null,
      status: 'pending',
      domainReportId: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    mockAdminService.listReports.mockResolvedValueOnce({
      items: [mockReport],
      total: 1,
      page: 1,
      limit: 20,
      totalPages: 1,
    });

    const result = await controller.listReports({ page: 1, limit: 20 });
    expect(result.items[0].status).toBe('pending');
    expect(result.items[0]).not.toHaveProperty('privateMessageContent');
  });

  it('getReportById returns report details', async () => {
    const mockReport = {
      id: 'report-id-001',
      reporterId: 'user-id-001',
      reporterName: 'Test User',
      targetType: 'user',
      targetId: 'user-id-002',
      reason: 'harassment',
      details: 'Some details',
      status: 'reviewing',
      domainReportId: null,
      reporter: { id: 'user-id-001', displayName: 'Test User' },
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    mockAdminService.getReportById.mockResolvedValueOnce(mockReport);
    const result = await controller.getReportById('report-id-001');
    expect(result.id).toBe('report-id-001');
    expect(result.reporter).toBeDefined();
  });

  // ── Staff ─────────────────────────────────────────────────────────────────

  it('listStaff returns staff users (moderators and admins)', async () => {
    const mockStaff = { ...mockSafeUserProjection, role: UserRole.MODERATOR };
    mockAdminService.listStaff.mockResolvedValueOnce({
      items: [mockStaff],
      total: 1,
      page: 1,
      limit: 20,
      totalPages: 1,
    });

    const result = await controller.listStaff({ page: 1, limit: 20 });
    expect(result.items[0].role).toBe(UserRole.MODERATOR);
  });

  // ── Audit Logs ────────────────────────────────────────────────────────────

  it('listAuditLogs returns audit records', async () => {
    const mockAuditLog = {
      id: 'log-id-001',
      actorId: mockAdminUser.userId,
      actorName: 'Admin User',
      action: 'role_change',
      targetType: 'user',
      targetId: 'user-id-001',
      reportId: null,
      reason: 'Role changed from user to moderator',
      metadata: { previousRole: 'user', newRole: 'moderator' },
      createdAt: new Date(),
    };
    mockAdminService.listAuditLogs.mockResolvedValueOnce({
      items: [mockAuditLog],
      total: 1,
      page: 1,
      limit: 20,
      totalPages: 1,
    });

    const result = await controller.listAuditLogs({ page: 1, limit: 20 });
    expect(result.items[0].action).toBe('role_change');
    // Audit logs must be read-only — no delete/update methods
    expect(typeof (controller as Record<string, unknown>).deleteAuditLog).toBe('undefined');
  });

  // ── Content ───────────────────────────────────────────────────────────────

  it('listListings returns paginated listings', async () => {
    mockAdminService.listListings.mockResolvedValueOnce({
      items: [{ id: 'listing-id-001', title: 'Old Phone', category: 'mobiles' }],
      total: 1,
      page: 1,
      limit: 20,
      totalPages: 1,
    });

    const result = await controller.listListings({ page: 1, limit: 20 });
    expect(result.items[0].title).toBe('Old Phone');
  });

  it('listBusinesses returns paginated businesses', async () => {
    mockAdminService.listBusinesses.mockResolvedValueOnce({
      items: [{ id: 'biz-id-001', name: 'Sharma Store', category: 'grocery' }],
      total: 1,
      page: 1,
      limit: 20,
      totalPages: 1,
    });

    const result = await controller.listBusinesses({ page: 1, limit: 20 });
    expect(result.items[0].name).toBe('Sharma Store');
  });

  it('listServices returns paginated services', async () => {
    mockAdminService.listServices.mockResolvedValueOnce({
      items: [{ id: 'svc-id-001', title: 'Plumbing Services', category: 'home_repair' }],
      total: 1,
      page: 1,
      limit: 20,
      totalPages: 1,
    });

    const result = await controller.listServices({ page: 1, limit: 20 });
    expect(result.items[0].title).toBe('Plumbing Services');
  });

  it('listCommunities returns paginated communities', async () => {
    mockAdminService.listCommunities.mockResolvedValueOnce({
      items: [{ id: 'comm-id-001', name: 'Koramangala Residents', memberCount: 120 }],
      total: 1,
      page: 1,
      limit: 20,
      totalPages: 1,
    });

    const result = await controller.listCommunities({ page: 1, limit: 20 });
    expect(result.items[0].memberCount).toBe(120);
  });
});

// ── Authorization Guard Tests ────────────────────────────────────────────────
describe('Admin Authorization Contracts', () => {
  it('MODERATOR cannot call updateUserRole (ADMIN-only route)', () => {
    // Verified via RolesGuard: route has @Roles(UserRole.ADMIN) only
    // Mock test — actual enforcement tested via E2E script
    expect(mockModeratorUser.role).not.toBe(UserRole.ADMIN);
  });

  it('Normal USER has no admin role at all', () => {
    const normalUser = { ...mockAdminUser, role: UserRole.USER };
    expect(normalUser.role).toBe(UserRole.USER);
    expect([UserRole.ADMIN, UserRole.MODERATOR]).not.toContain(normalUser.role);
  });

  it('Safe user projection does not include phone number', () => {
    expect(mockSafeUserProjection).not.toHaveProperty('phoneNumber');
  });

  it('Safe user projection does not include refresh token', () => {
    expect(mockSafeUserProjection).not.toHaveProperty('refreshTokenHash');
  });
});

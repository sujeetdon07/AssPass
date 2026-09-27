import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike, FindOptionsWhere } from 'typeorm';

import { User, UserRole, UserStatus } from '../users/entities/user.entity.js';
import {
  SafetyReport,
  SafetyModerationStatus,
} from '../safety/entities/safety-report.entity.js';
import { ModerationAuditLog } from '../safety/entities/moderation-audit-log.entity.js';
import { Post } from '../feed/entities/post.entity.js';
import { Comment } from '../feed/entities/comment.entity.js';
import { MarketplaceListing } from '../marketplace/entities/marketplace-listing.entity.js';
import { Business } from '../businesses/entities/business.entity.js';
import { ServiceListing } from '../services/entities/service-listing.entity.js';
import { Community } from '../communities/entities/community.entity.js';
import {
  SafetyReportTargetType,
} from '../safety/dto/create-safety-report.dto.js';
import { RedisService } from '../../database/redis.service.js';

export interface AdminPaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

// Safe user projection — never exposes credentials, exact coords, or tokens
export interface AdminUserProjection {
  id: string;
  displayName: string | null;
  avatarUrl: string | null;
  role: UserRole;
  accountStatus: UserStatus;
  onboardingCompleted: boolean;
  locality: string | null;
  city: string | null;
  state: string | null;
  countryCode: string | null;
  lastLoginAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface AdminReportProjection {
  id: string;
  reporterId: string;
  reporterName: string | null;
  targetType: string;
  targetId: string;
  reason: string;
  details: string | null;
  status: SafetyModerationStatus;
  domainReportId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface AdminAuditLogProjection {
  id: string;
  actorId: string;
  actorName: string | null;
  action: string;
  targetType: string;
  targetId: string;
  reportId: string | null;
  reason: string | null;
  metadata: Record<string, unknown> | null;
  createdAt: Date;
}

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);
  private readonly dashboardCacheKey = 'admin:dashboard:summary';
  private readonly dashboardCacheTtl = 30; // 30 seconds TTL

  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(SafetyReport)
    private readonly reportRepo: Repository<SafetyReport>,
    @InjectRepository(ModerationAuditLog)
    private readonly auditRepo: Repository<ModerationAuditLog>,
    @InjectRepository(Post)
    private readonly postRepo: Repository<Post>,
    @InjectRepository(Comment)
    private readonly commentRepo: Repository<Comment>,
    @InjectRepository(MarketplaceListing)
    private readonly listingRepo: Repository<MarketplaceListing>,
    @InjectRepository(Business)
    private readonly businessRepo: Repository<Business>,
    @InjectRepository(ServiceListing)
    private readonly serviceRepo: Repository<ServiceListing>,
    @InjectRepository(Community)
    private readonly communityRepo: Repository<Community>,
    private readonly redisService: RedisService,
  ) {}

  // ── Dashboard Summary ───────────────────────────────────────────────────────

  async getDashboardSummary() {
    // 1. Check Redis cache first
    try {
      const cached = await this.redisService.get(this.dashboardCacheKey);
      if (cached) {
        return JSON.parse(cached);
      }
    } catch (err: any) {
      this.logger.warn(`Redis dashboard cache lookup failed: ${err.message}`);
    }

    const [
      totalUsers,
      activeUsers,
      suspendedUsers,
      pendingReports,
      reviewingReports,
      actionedReports,
      totalListings,
      totalBusinesses,
      totalServices,
      totalCommunities,
    ] = await Promise.all([
      this.userRepo.count(),
      this.userRepo.count({ where: { accountStatus: UserStatus.ACTIVE } }),
      this.userRepo.count({ where: { accountStatus: UserStatus.SUSPENDED } }),
      this.reportRepo.count({ where: { status: SafetyModerationStatus.PENDING } }),
      this.reportRepo.count({ where: { status: SafetyModerationStatus.REVIEWING } }),
      this.reportRepo.count({ where: { status: SafetyModerationStatus.ACTIONED } }),
      this.listingRepo.count({ where: { deletedAt: undefined } }),
      this.businessRepo.count({ where: { deletedAt: undefined } }),
      this.serviceRepo.count({ where: { deletedAt: undefined } }),
      this.communityRepo.count(),
    ]);

    // Recent moderation activity (last 10 audit entries)
    const recentActivity = await this.auditRepo.find({
      order: { createdAt: 'DESC' },
      take: 10,
    });

    // New users in last 7 days
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const newUsersThisWeek = await this.userRepo
      .createQueryBuilder('u')
      .where('u.createdAt >= :date', { date: sevenDaysAgo })
      .getCount();

    const summary = {
      users: {
        total: totalUsers,
        active: activeUsers,
        suspended: suspendedUsers,
        newThisWeek: newUsersThisWeek,
      },
      moderation: {
        pending: pendingReports,
        reviewing: reviewingReports,
        actioned: actionedReports,
      },
      content: {
        listings: totalListings,
        businesses: totalBusinesses,
        services: totalServices,
        communities: totalCommunities,
      },
      recentActivity: recentActivity.map((log) => this.projectAuditLog(log, null)),
    };

    // Cache summary in Redis
    try {
      await this.redisService.set(
        this.dashboardCacheKey,
        JSON.stringify(summary),
        this.dashboardCacheTtl,
      );
    } catch (err: any) {
      this.logger.warn(`Redis dashboard cache write failed: ${err.message}`);
    }

    return summary;
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  async listUsers(
    page: number,
    limit: number,
    search?: string,
    role?: UserRole,
    status?: UserStatus,
  ): Promise<AdminPaginatedResult<AdminUserProjection>> {
    const skip = (page - 1) * limit;
    const where: FindOptionsWhere<User>[] = [];

    if (search) {
      // Search by displayName or id prefix
      if (search.length > 8 && search.includes('-')) {
        // Looks like a UUID
        where.push({ id: search, ...(role ? { role } : {}), ...(status ? { accountStatus: status } : {}) });
      } else {
        where.push({
          displayName: ILike(`%${search}%`),
          ...(role ? { role } : {}),
          ...(status ? { accountStatus: status } : {}),
        });
      }
    } else {
      const baseWhere: FindOptionsWhere<User> = {};
      if (role) baseWhere.role = role;
      if (status) baseWhere.accountStatus = status;
      where.push(baseWhere);
    }

    const [users, total] = await this.userRepo.findAndCount({
      where: where.length === 1 ? where[0] : where,
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    return {
      items: users.map((u) => this.projectUser(u)),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getUserById(userId: string): Promise<AdminUserProjection> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException(`User ${userId} not found.`);
    return this.projectUser(user);
  }

  async getUserReportHistory(
    userId: string,
    page: number,
    limit: number,
  ): Promise<AdminPaginatedResult<AdminReportProjection>> {
    const skip = (page - 1) * limit;
    const [reports, total] = await this.reportRepo.findAndCount({
      where: { reporterId: userId },
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    const reporterUser = await this.userRepo.findOne({ where: { id: userId } });

    return {
      items: reports.map((r) =>
        this.projectReport(r, reporterUser?.displayName ?? null),
      ),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async updateUserRole(
    actorId: string,
    targetUserId: string,
    newRole: UserRole,
    actorRole: UserRole,
  ): Promise<AdminUserProjection> {
    if (actorId === targetUserId) {
      throw new BadRequestException('You cannot change your own role.');
    }

    const target = await this.userRepo.findOne({ where: { id: targetUserId } });
    if (!target) throw new NotFoundException(`User ${targetUserId} not found.`);

    // Only ADMIN can promote to ADMIN or demote from ADMIN
    if (newRole === UserRole.ADMIN || target.role === UserRole.ADMIN) {
      if (actorRole !== UserRole.ADMIN) {
        throw new ForbiddenException(
          'Only ADMIN can assign or revoke the ADMIN role.',
        );
      }
    }

    const previousRole = target.role;
    target.role = newRole;
    await this.userRepo.save(target);

    // Audit log
    await this.auditRepo.save(
      this.auditRepo.create({
        actorId,
        action: 'role_change',
        targetType: 'user',
        targetId: targetUserId,
        reason: `Role changed from ${previousRole} to ${newRole}`,
        metadata: { previousRole, newRole },
      }),
    );

    // Invalidate dashboard summary cache
    await this.redisService.del(this.dashboardCacheKey);

    this.logger.log(
      `[AdminService] Actor ${actorId} changed role of user ${targetUserId}: ${previousRole} → ${newRole}`,
    );

    return this.projectUser(target);
  }

  async updateUserStatus(
    actorId: string,
    targetUserId: string,
    newStatus: UserStatus,
    reason: string,
  ): Promise<AdminUserProjection> {
    if (actorId === targetUserId) {
      throw new BadRequestException('You cannot suspend/restore yourself.');
    }

    const target = await this.userRepo.findOne({ where: { id: targetUserId } });
    if (!target) throw new NotFoundException(`User ${targetUserId} not found.`);

    const previousStatus = target.accountStatus;
    target.accountStatus = newStatus;
    await this.userRepo.save(target);

    // Audit log
    await this.auditRepo.save(
      this.auditRepo.create({
        actorId,
        action:
          newStatus === UserStatus.SUSPENDED
            ? 'user_suspended'
            : newStatus === UserStatus.ACTIVE
              ? 'user_restored'
              : 'user_status_changed',
        targetType: 'user',
        targetId: targetUserId,
        reason,
        metadata: { previousStatus, newStatus },
      }),
    );

    // Invalidate dashboard summary cache
    await this.redisService.del(this.dashboardCacheKey);

    this.logger.log(
      `[AdminService] Actor ${actorId} changed status of user ${targetUserId}: ${previousStatus} → ${newStatus}`,
    );

    return this.projectUser(target);
  }

  // ── Reports ────────────────────────────────────────────────────────────────

  async listReports(
    page: number,
    limit: number,
    status?: SafetyModerationStatus,
    targetType?: SafetyReportTargetType,
    reason?: string,
  ): Promise<AdminPaginatedResult<AdminReportProjection>> {
    const skip = (page - 1) * limit;
    const where: FindOptionsWhere<SafetyReport> = {};
    if (status) where.status = status;
    if (targetType) where.targetType = targetType;
    if (reason) where.reason = reason as any;

    const [reports, total] = await this.reportRepo.findAndCount({
      where,
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    // Batch-load reporter names
    const reporterIds = [...new Set(reports.map((r) => r.reporterId))];
    const reporters =
      reporterIds.length > 0
        ? await this.userRepo.findByIds(reporterIds)
        : [];
    const reporterMap = new Map(reporters.map((u) => [u.id, u.displayName ?? null]));

    return {
      items: reports.map((r) =>
        this.projectReport(r, reporterMap.get(r.reporterId) ?? null),
      ),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getReportById(reportId: string): Promise<AdminReportProjection & { reporter?: { id: string; displayName: string | null } }> {
    const report = await this.reportRepo.findOne({ where: { id: reportId } });
    if (!report) throw new NotFoundException(`Report ${reportId} not found.`);

    const reporter = await this.userRepo.findOne({
      where: { id: report.reporterId },
    });

    return {
      ...this.projectReport(report, reporter?.displayName ?? null),
      reporter: reporter
        ? { id: reporter.id, displayName: reporter.displayName ?? null }
        : undefined,
    };
  }

  // ── Staff ──────────────────────────────────────────────────────────────────

  async listStaff(
    page: number,
    limit: number,
  ): Promise<AdminPaginatedResult<AdminUserProjection>> {
    const skip = (page - 1) * limit;
    const [staff, total] = await this.userRepo.findAndCount({
      where: [{ role: UserRole.MODERATOR }, { role: UserRole.ADMIN }],
      order: { role: 'ASC', createdAt: 'ASC' },
      skip,
      take: limit,
    });

    return {
      items: staff.map((u) => this.projectUser(u)),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  // ── Audit Logs ─────────────────────────────────────────────────────────────

  async listAuditLogs(
    page: number,
    limit: number,
    actorId?: string,
    action?: string,
    targetType?: string,
  ): Promise<AdminPaginatedResult<AdminAuditLogProjection>> {
    const skip = (page - 1) * limit;
    const where: FindOptionsWhere<ModerationAuditLog> = {};
    if (actorId) where.actorId = actorId;
    if (action) where.action = action;
    if (targetType) where.targetType = targetType;

    const [logs, total] = await this.auditRepo.findAndCount({
      where,
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    // Batch-load actor names
    const actorIds = [...new Set(logs.map((l) => l.actorId))];
    const actors =
      actorIds.length > 0
        ? await this.userRepo.findByIds(actorIds)
        : [];
    const actorMap = new Map(actors.map((u) => [u.id, u.displayName ?? null]));

    return {
      items: logs.map((l) =>
        this.projectAuditLog(l, actorMap.get(l.actorId) ?? null),
      ),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  // ── Content ────────────────────────────────────────────────────────────────

  async listListings(
    page: number,
    limit: number,
    search?: string,
  ) {
    const skip = (page - 1) * limit;
    const qb = this.listingRepo.createQueryBuilder('l')
      .withDeleted()
      .orderBy('l.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    if (search) {
      qb.where('l.title ILIKE :search', { search: `%${search}%` });
    }

    const [items, total] = await qb.getManyAndCount();

    return {
      items: items.map((l) => ({
        id: l.id,
        title: l.title,
        category: l.category,
        status: l.status,
        condition: l.condition,
        price: l.price,
        currency: l.currency,
        sellerId: l.sellerId,
        city: l.city,
        locality: l.locality,
        createdAt: l.createdAt,
        deletedAt: l.deletedAt ?? null,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async listBusinesses(
    page: number,
    limit: number,
    search?: string,
  ) {
    const skip = (page - 1) * limit;
    const qb = this.businessRepo.createQueryBuilder('b')
      .withDeleted()
      .orderBy('b.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    if (search) {
      qb.where('b.name ILIKE :search', { search: `%${search}%` });
    }

    const [items, total] = await qb.getManyAndCount();

    return {
      items: items.map((b) => ({
        id: b.id,
        name: b.name,
        slug: b.slug,
        category: b.category,
        status: b.status,
        verificationStatus: b.verificationStatus,
        ownerId: b.ownerId,
        city: b.city,
        locality: b.locality,
        createdAt: b.createdAt,
        deletedAt: b.deletedAt ?? null,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async listServices(
    page: number,
    limit: number,
    search?: string,
  ) {
    const skip = (page - 1) * limit;
    const qb = this.serviceRepo.createQueryBuilder('s')
      .withDeleted()
      .orderBy('s.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    if (search) {
      qb.where('s.title ILIKE :search', { search: `%${search}%` });
    }

    const [items, total] = await qb.getManyAndCount();

    return {
      items: items.map((s) => ({
        id: s.id,
        title: s.title,
        category: s.category,
        status: s.status,
        verificationStatus: s.verificationStatus,
        ownerId: s.ownerId,
        city: s.city,
        locality: s.locality,
        startingPrice: s.startingPrice,
        currency: s.currency,
        createdAt: s.createdAt,
        deletedAt: s.deletedAt ?? null,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async listCommunities(
    page: number,
    limit: number,
    search?: string,
  ) {
    const skip = (page - 1) * limit;
    const qb = this.communityRepo.createQueryBuilder('c')
      .orderBy('c.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    if (search) {
      qb.where('c.name ILIKE :search', { search: `%${search}%` });
    }

    const [items, total] = await qb.getManyAndCount();

    return {
      items: items.map((c) => ({
        id: c.id,
        name: c.name,
        slug: c.slug,
        category: c.category,
        visibility: c.visibility,
        status: c.status,
        memberCount: c.memberCount,
        postCount: c.postCount,
        creatorId: c.creatorId,
        city: c.city,
        locality: c.locality,
        createdAt: c.createdAt,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  // ── Private Projectors ─────────────────────────────────────────────────────

  private projectUser(user: User): AdminUserProjection {
    return {
      id: user.id,
      displayName: user.displayName ?? null,
      avatarUrl: user.avatarUrl ?? null,
      role: user.role,
      accountStatus: user.accountStatus,
      onboardingCompleted: user.onboardingCompleted,
      locality: user.locality ?? null,
      city: user.city ?? null,
      state: user.state ?? null,
      countryCode: user.countryCode ?? null,
      lastLoginAt: user.lastLoginAt ?? null,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
    // NOTE: phoneNumber, exact GPS coordinates, FCM tokens, and refresh
    // token hashes are intentionally omitted from the admin projection.
  }

  private projectReport(
    report: SafetyReport,
    reporterName: string | null,
  ): AdminReportProjection {
    return {
      id: report.id,
      reporterId: report.reporterId,
      reporterName,
      targetType: report.targetType,
      targetId: report.targetId,
      reason: report.reason,
      details: report.details ?? null,
      status: report.status,
      domainReportId: report.domainReportId ?? null,
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
    };
  }

  private projectAuditLog(
    log: ModerationAuditLog,
    actorName: string | null,
  ): AdminAuditLogProjection {
    return {
      id: log.id,
      actorId: log.actorId,
      actorName,
      action: log.action,
      targetType: log.targetType,
      targetId: log.targetId,
      reportId: log.reportId ?? null,
      reason: log.reason ?? null,
      metadata: log.metadata as Record<string, unknown> | null,
      createdAt: log.createdAt,
    };
  }
}

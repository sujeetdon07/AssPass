import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';

// Safety Entities
import {
  SafetyReport,
  SafetyModerationStatus,
} from './entities/safety-report.entity.js';
import { ModerationAuditLog } from './entities/moderation-audit-log.entity.js';

// Domain Entities
import { UserBlock } from '../messaging/entities/user-block.entity.js';
import { User } from '../users/entities/user.entity.js';
import { Report, ReportTargetType, ReportStatus } from '../feed/entities/report.entity.js';
import { Post } from '../feed/entities/post.entity.js';
import { Comment } from '../feed/entities/comment.entity.js';
import {
  MarketplaceReport,
  MarketplaceReportStatus,
} from '../marketplace/entities/marketplace-report.entity.js';
import { MarketplaceListing } from '../marketplace/entities/marketplace-listing.entity.js';
import {
  BusinessReport,
  BusinessReportStatus,
} from '../businesses/entities/business-report.entity.js';
import { Business } from '../businesses/entities/business.entity.js';
import {
  ServiceReport,
  ServiceReportStatus,
} from '../services/entities/service-report.entity.js';
import { ServiceListing } from '../services/entities/service-listing.entity.js';
import { Conversation } from '../messaging/entities/conversation.entity.js';
import { Message } from '../messaging/entities/message.entity.js';
import {
  ConversationReport,
  ConversationReportStatus,
  ConversationReportReason,
} from '../messaging/entities/conversation-report.entity.js';
import { Event } from '../events/entities/event.entity.js';

import { RedisService } from '../../database/redis.service.js';
import {
  CreateSafetyReportDto,
  SafetyReportTargetType,
  SafetyReportReason,
} from './dto/create-safety-report.dto.js';
import {
  toPublicProfile,
  PublicProfileProjection,
} from '../messaging/serializers/public-profile.serializer.js';

export interface BlockedUserRecord {
  blockId: string;
  blockedAt: Date;
  blockedUser: PublicProfileProjection;
}

export interface UserReportHistoryItem {
  id: string;
  targetType: SafetyReportTargetType;
  targetId: string;
  reason: SafetyReportReason;
  details?: string | null;
  status: SafetyModerationStatus;
  createdAt: Date;
}

@Injectable()
export class SafetyService {
  private readonly logger = new Logger(SafetyService.name);

  // Rate limiting: 10 safety reports per user per rolling 1-hour window
  private readonly maxReportsPerHour = 10;
  private readonly reportRateLimitWindowSeconds = 3600;

  constructor(
    @InjectRepository(SafetyReport)
    private readonly safetyReportRepo: Repository<SafetyReport>,
    @InjectRepository(ModerationAuditLog)
    private readonly auditLogRepo: Repository<ModerationAuditLog>,
    @InjectRepository(UserBlock)
    private readonly blockRepo: Repository<UserBlock>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Report)
    private readonly feedReportRepo: Repository<Report>,
    @InjectRepository(Post)
    private readonly postRepo: Repository<Post>,
    @InjectRepository(Comment)
    private readonly commentRepo: Repository<Comment>,
    @InjectRepository(MarketplaceReport)
    private readonly marketplaceReportRepo: Repository<MarketplaceReport>,
    @InjectRepository(MarketplaceListing)
    private readonly marketplaceListingRepo: Repository<MarketplaceListing>,
    @InjectRepository(BusinessReport)
    private readonly businessReportRepo: Repository<BusinessReport>,
    @InjectRepository(Business)
    private readonly businessRepo: Repository<Business>,
    @InjectRepository(ServiceReport)
    private readonly serviceReportRepo: Repository<ServiceReport>,
    @InjectRepository(ServiceListing)
    private readonly serviceRepo: Repository<ServiceListing>,
    @InjectRepository(Conversation)
    private readonly conversationRepo: Repository<Conversation>,
    @InjectRepository(Message)
    private readonly messageRepo: Repository<Message>,
    @InjectRepository(ConversationReport)
    private readonly conversationReportRepo: Repository<ConversationReport>,
    @InjectRepository(Event)
    private readonly eventRepo: Repository<Event>,
    private readonly redisService: RedisService,
  ) {}

  // ── Block Management ─────────────────────────────────────────────────────────

  /**
   * Block a user. Idempotent — blocking an already-blocked user returns success.
   */
  async blockUser(
    blockerId: string,
    blockedId: string,
  ): Promise<{ success: boolean; message: string }> {
    if (blockerId === blockedId) {
      throw new BadRequestException('You cannot block yourself.');
    }

    const target = await this.userRepo.findOne({ where: { id: blockedId } });
    if (!target) {
      throw new NotFoundException('Target user not found.');
    }

    const existing = await this.blockRepo.findOne({
      where: { blockerId, blockedId },
    });

    if (!existing) {
      const block = this.blockRepo.create({ blockerId, blockedId });
      await this.blockRepo.save(block);
      await this.recordAuditLog(
        blockerId,
        'user_blocked',
        'user',
        blockedId,
      );
      this.logger.log(`User ${blockerId} blocked user [redacted].`);
    }

    return { success: true, message: 'User blocked successfully.' };
  }

  /**
   * Unblock a previously blocked user. Idempotent.
   */
  async unblockUser(
    blockerId: string,
    blockedId: string,
  ): Promise<{ success: boolean; message: string }> {
    if (blockerId === blockedId) {
      throw new BadRequestException('Invalid request.');
    }

    await this.blockRepo.delete({ blockerId, blockedId });
    await this.recordAuditLog(
      blockerId,
      'user_unblocked',
      'user',
      blockedId,
    );
    return { success: true, message: 'User unblocked successfully.' };
  }

  /**
   * Return a paginated list of users blocked by the current user.
   * Responses are safe public projections — no phone numbers, email, or PII.
   */
  async getBlockedUsers(
    blockerId: string,
    limit: number = 20,
    cursor?: string,
  ): Promise<{
    items: BlockedUserRecord[];
    nextCursor: string | null;
    hasMore: boolean;
  }> {
    const qb = this.blockRepo
      .createQueryBuilder('block')
      .leftJoinAndSelect('block.blocked', 'blocked')
      .where('block.blockerId = :blockerId', { blockerId })
      .orderBy('block.createdAt', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(cursor);
      if (!isNaN(cursorDate.getTime())) {
        qb.andWhere('block.createdAt < :cursor', { cursor: cursorDate });
      }
    }

    const rawItems = await qb.getMany();
    const hasMore = rawItems.length > limit;
    const items = hasMore ? rawItems.slice(0, limit) : rawItems;

    const records: BlockedUserRecord[] = items.map((block) => ({
      blockId: block.id,
      blockedAt: block.createdAt,
      blockedUser: toPublicProfile(block.blocked),
    }));

    const nextCursor =
      hasMore && items.length > 0
        ? items[items.length - 1]!.createdAt.toISOString()
        : null;

    return { items: records, nextCursor, hasMore };
  }

  /**
   * Check whether user A has blocked user B or vice-versa.
   */
  async isBlocked(userA: string, userB: string): Promise<boolean> {
    const block = await this.blockRepo.findOne({
      where: [
        { blockerId: userA, blockedId: userB },
        { blockerId: userB, blockedId: userA },
      ],
    });
    return !!block;
  }

  /**
   * Assert that no block exists between two users; otherwise throw ForbiddenException.
   */
  async assertNotBlocked(userA: string, userB: string): Promise<void> {
    if (await this.isBlocked(userA, userB)) {
      throw new ForbiddenException('Interaction unavailable: user is blocked.');
    }
  }

  // ── Unified Content & User Reporting ─────────────────────────────────────────

  /**
   * Submit a safety report for any entity/content type.
   *
   * Validates target existence and authorization, enforces per-user rate limit,
   * detects duplicates (active reports), writes to central safety_reports and
   * domain-specific tables, and records an internal audit log.
   */
  async submitReport(
    reporterId: string,
    dto: CreateSafetyReportDto,
  ): Promise<{ success: boolean; message: string; reportId: string }> {
    // 1. Rate limiting check
    await this.checkReportRateLimit(reporterId);

    // 2. Target validation
    await this.validateTarget(reporterId, dto);

    // 3. Deduplication: check for existing active report by this reporter for same target
    const existingActiveReport = await this.safetyReportRepo.findOne({
      where: {
        reporterId,
        targetType: dto.targetType,
        targetId: dto.targetId,
        status: In([SafetyModerationStatus.PENDING, SafetyModerationStatus.REVIEWING]),
      },
    });

    if (existingActiveReport) {
      throw new ConflictException(
        'You have already submitted an active report for this content. Our moderation team is reviewing it.',
      );
    }

    // 4. Create centralized SafetyReport
    const safetyReport = this.safetyReportRepo.create({
      reporterId,
      targetType: dto.targetType,
      targetId: dto.targetId,
      secondaryId: dto.secondaryId ?? null,
      reason: dto.reason,
      details: dto.details ?? null,
      status: SafetyModerationStatus.PENDING,
    });

    // 5. Route to domain-specific report table (for peer module integration)
    const domainReportId = await this.routeToDomainReport(reporterId, dto);
    if (domainReportId) {
      safetyReport.domainReportId = domainReportId;
    }

    const savedReport = await this.safetyReportRepo.save(safetyReport);

    // 6. Record moderation audit trail
    await this.recordAuditLog(
      reporterId,
      'report_submitted',
      dto.targetType,
      dto.targetId,
      savedReport.id,
      dto.reason,
    );

    // 7. Increment rate limit counter
    await this.incrementReportRateLimit(reporterId);

    // 8. Invalidate admin dashboard cache
    await this.redisService.del('admin:dashboard:summary');

    return {
      success: true,
      message: this.successMessage(),
      reportId: savedReport.id,
    };
  }

  /**
   * Return paginated report history for the authenticated user.
   * Strictly excludes reviewer identity, internal moderation notes, and private message data.
   */
  async getMyReports(
    reporterId: string,
    limit: number = 20,
    cursor?: string,
  ): Promise<{
    items: UserReportHistoryItem[];
    nextCursor: string | null;
    hasMore: boolean;
  }> {
    const qb = this.safetyReportRepo
      .createQueryBuilder('report')
      .where('report.reporterId = :reporterId', { reporterId })
      .orderBy('report.createdAt', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(cursor);
      if (!isNaN(cursorDate.getTime())) {
        qb.andWhere('report.createdAt < :cursor', { cursor: cursorDate });
      }
    }

    const rawItems = await qb.getMany();
    const hasMore = rawItems.length > limit;
    const items = hasMore ? rawItems.slice(0, limit) : rawItems;

    const historyItems: UserReportHistoryItem[] = items.map((r) => ({
      id: r.id,
      targetType: r.targetType,
      targetId: r.targetId,
      reason: r.reason,
      details: r.details,
      status: r.status,
      createdAt: r.createdAt,
    }));

    const nextCursor =
      hasMore && items.length > 0
        ? items[items.length - 1]!.createdAt.toISOString()
        : null;

    return { items: historyItems, nextCursor, hasMore };
  }

  // ── Moderation Lifecycle & Audit (Phase 11 Foundation) ────────────────────────

  /**
   * Update moderation status of a report. Restricted to MODERATOR / ADMIN roles.
   */
  async updateReportStatus(
    reportId: string,
    status: SafetyModerationStatus,
    actorId: string,
    reason?: string,
  ): Promise<{ success: boolean; report: SafetyReport }> {
    const report = await this.safetyReportRepo.findOne({ where: { id: reportId } });
    if (!report) {
      throw new NotFoundException('Report not found.');
    }

    report.status = status;
    const updated = await this.safetyReportRepo.save(report);

    await this.recordAuditLog(
      actorId,
      `report_${status.toLowerCase()}`,
      report.targetType,
      report.targetId,
      report.id,
      reason,
    );

    // Invalidate admin dashboard cache
    await this.redisService.del('admin:dashboard:summary');

    return { success: true, report: updated };
  }

  /**
   * Query moderation audit logs. Restricted to MODERATOR / ADMIN roles.
   */
  async getAuditLogs(
    limit: number = 20,
    cursor?: string,
  ): Promise<{ items: ModerationAuditLog[]; nextCursor: string | null; hasMore: boolean }> {
    const qb = this.auditLogRepo
      .createQueryBuilder('log')
      .orderBy('log.createdAt', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(cursor);
      if (!isNaN(cursorDate.getTime())) {
        qb.andWhere('log.createdAt < :cursor', { cursor: cursorDate });
      }
    }

    const raw = await qb.getMany();
    const hasMore = raw.length > limit;
    const items = hasMore ? raw.slice(0, limit) : raw;
    const nextCursor =
      hasMore && items.length > 0
        ? items[items.length - 1]!.createdAt.toISOString()
        : null;

    return { items, nextCursor, hasMore };
  }

  // ── Private Validation & Routing Helpers ─────────────────────────────────────

  private async validateTarget(
    reporterId: string,
    dto: CreateSafetyReportDto,
  ): Promise<void> {
    switch (dto.targetType) {
      case SafetyReportTargetType.USER: {
        if (reporterId === dto.targetId) {
          throw new BadRequestException('You cannot report yourself.');
        }
        const user = await this.userRepo.findOne({ where: { id: dto.targetId } });
        if (!user) {
          throw new NotFoundException('Target user not found.');
        }
        break;
      }

      case SafetyReportTargetType.POST: {
        const post = await this.postRepo.findOne({ where: { id: dto.targetId } });
        if (!post) {
          throw new NotFoundException('Report target not found.');
        }
        break;
      }

      case SafetyReportTargetType.COMMENT: {
        const comment = await this.commentRepo.findOne({ where: { id: dto.targetId } });
        if (!comment) {
          throw new NotFoundException('Report target not found.');
        }
        break;
      }

      case SafetyReportTargetType.LISTING: {
        const listing = await this.marketplaceListingRepo.findOne({
          where: { id: dto.targetId },
        });
        if (!listing) {
          throw new NotFoundException('Report target not found.');
        }
        break;
      }

      case SafetyReportTargetType.BUSINESS: {
        const business = await this.businessRepo.findOne({ where: { id: dto.targetId } });
        if (!business) {
          throw new NotFoundException('Report target not found.');
        }
        break;
      }

      case SafetyReportTargetType.SERVICE: {
        const service = await this.serviceRepo.findOne({ where: { id: dto.targetId } });
        if (!service) {
          throw new NotFoundException('Report target not found.');
        }
        break;
      }

      case SafetyReportTargetType.CONVERSATION: {
        const conv = await this.conversationRepo.findOne({ where: { id: dto.targetId } });
        if (!conv) {
          throw new NotFoundException('Conversation not found.');
        }
        if (conv.user1Id !== reporterId && conv.user2Id !== reporterId) {
          throw new ForbiddenException('You can only report conversations you participate in.');
        }
        break;
      }

      case SafetyReportTargetType.MESSAGE: {
        const msg = await this.messageRepo.findOne({ where: { id: dto.targetId } });
        if (!msg) {
          throw new NotFoundException('Message not found.');
        }
        const conv = await this.conversationRepo.findOne({ where: { id: msg.conversationId } });
        if (!conv || (conv.user1Id !== reporterId && conv.user2Id !== reporterId)) {
          throw new ForbiddenException('You can only report messages in conversations you participate in.');
        }
        break;
      }

      case SafetyReportTargetType.EVENT: {
        const event = await this.eventRepo.findOne({ where: { id: dto.targetId } });
        if (!event) {
          throw new NotFoundException('Event not found.');
        }
        if (event.creatorId === reporterId) {
          throw new BadRequestException('You cannot report your own event.');
        }
        break;
      }

      default:
        throw new BadRequestException('Unsupported report target type.');
    }
  }

  private async routeToDomainReport(
    reporterId: string,
    dto: CreateSafetyReportDto,
  ): Promise<string | null> {
    try {
      switch (dto.targetType) {
        case SafetyReportTargetType.POST: {
          const report = this.feedReportRepo.create({
            reporterId,
            targetType: ReportTargetType.POST,
            targetId: dto.targetId,
            reason: this.mapToFeedReason(dto.reason),
            details: dto.details ?? null,
            status: ReportStatus.PENDING,
          });
          const saved = await this.feedReportRepo.save(report);
          return saved.id;
        }

        case SafetyReportTargetType.COMMENT: {
          const report = this.feedReportRepo.create({
            reporterId,
            targetType: ReportTargetType.COMMENT,
            targetId: dto.targetId,
            reason: this.mapToFeedReason(dto.reason),
            details: dto.details ?? null,
            status: ReportStatus.PENDING,
          });
          const saved = await this.feedReportRepo.save(report);
          return saved.id;
        }

        case SafetyReportTargetType.LISTING: {
          const report = this.marketplaceReportRepo.create({
            reporterId,
            listingId: dto.targetId,
            reason: this.mapToMarketplaceReason(dto.reason) as any,
            details: dto.details ?? null,
            status: MarketplaceReportStatus.PENDING,
          });
          const saved = await this.marketplaceReportRepo.save(report);
          return saved.id;
        }

        case SafetyReportTargetType.BUSINESS: {
          const report = this.businessReportRepo.create({
            reporterId,
            businessId: dto.targetId,
            reason: this.mapToBusinessReason(dto.reason) as any,
            details: dto.details ?? null,
            status: BusinessReportStatus.PENDING,
          });
          const saved = await this.businessReportRepo.save(report);
          return saved.id;
        }

        case SafetyReportTargetType.SERVICE: {
          const report = this.serviceReportRepo.create({
            reporterId,
            serviceId: dto.targetId,
            reason: this.mapToBusinessReason(dto.reason) as any,
            details: dto.details ?? null,
            status: ServiceReportStatus.PENDING,
          });
          const saved = await this.serviceReportRepo.save(report);
          return saved.id;
        }

        case SafetyReportTargetType.CONVERSATION:
        case SafetyReportTargetType.MESSAGE: {
          let convId = dto.targetId;
          let msgId: string | null = dto.secondaryId ?? null;
          if (dto.targetType === SafetyReportTargetType.MESSAGE) {
            const msg = await this.messageRepo.findOne({ where: { id: dto.targetId } });
            if (msg) {
              convId = msg.conversationId;
              msgId = msg.id;
            }
          }

          const report = this.conversationReportRepo.create({
            reporterId,
            conversationId: convId,
            messageId: msgId,
            reason: this.mapToConversationReason(dto.reason),
            description: dto.details ?? null,
            status: ConversationReportStatus.PENDING,
          });
          const saved = await this.conversationReportRepo.save(report);
          return saved.id;
        }

        default:
          return null;
      }
    } catch (err) {
      this.logger.warn(`Domain-specific report persistence failed; central report preserved: ${err}`);
      return null;
    }
  }

  private mapToFeedReason(reason: SafetyReportReason): any {
    const map: Record<string, string> = {
      [SafetyReportReason.SPAM]: 'spam',
      [SafetyReportReason.HARASSMENT]: 'harassment',
      [SafetyReportReason.HATE_OR_ABUSE]: 'harassment',
      [SafetyReportReason.THREATS]: 'harassment',
      [SafetyReportReason.SCAM_OR_FRAUD]: 'other',
      [SafetyReportReason.SEXUAL_CONTENT]: 'inappropriate',
      [SafetyReportReason.VIOLENCE]: 'inappropriate',
      [SafetyReportReason.ILLEGAL_ACTIVITY]: 'illegal_content',
      [SafetyReportReason.MISINFORMATION]: 'misleading',
      [SafetyReportReason.IMPERSONATION]: 'harassment',
      [SafetyReportReason.PRIVACY_VIOLATION]: 'harassment',
      [SafetyReportReason.INAPPROPRIATE_CONTENT]: 'inappropriate',
      [SafetyReportReason.OTHER]: 'other',
      // Aliases
      [SafetyReportReason.FRAUD]: 'other',
      [SafetyReportReason.INAPPROPRIATE]: 'inappropriate',
      [SafetyReportReason.MISLEADING]: 'misleading',
      [SafetyReportReason.ILLEGAL_CONTENT]: 'illegal_content',
    };
    return map[reason] ?? 'other';
  }

  private mapToMarketplaceReason(reason: SafetyReportReason): string {
    const map: Record<string, string> = {
      [SafetyReportReason.SPAM]: 'spam',
      [SafetyReportReason.HARASSMENT]: 'harassment',
      [SafetyReportReason.HATE_OR_ABUSE]: 'harassment',
      [SafetyReportReason.THREATS]: 'harassment',
      [SafetyReportReason.SCAM_OR_FRAUD]: 'scam',
      [SafetyReportReason.SEXUAL_CONTENT]: 'inappropriate',
      [SafetyReportReason.VIOLENCE]: 'inappropriate',
      [SafetyReportReason.ILLEGAL_ACTIVITY]: 'inappropriate',
      [SafetyReportReason.MISINFORMATION]: 'misinformation',
      [SafetyReportReason.IMPERSONATION]: 'scam',
      [SafetyReportReason.PRIVACY_VIOLATION]: 'harassment',
      [SafetyReportReason.INAPPROPRIATE_CONTENT]: 'inappropriate',
      [SafetyReportReason.OTHER]: 'other',
      // Aliases
      [SafetyReportReason.FRAUD]: 'scam',
      [SafetyReportReason.INAPPROPRIATE]: 'inappropriate',
      [SafetyReportReason.MISLEADING]: 'misinformation',
      [SafetyReportReason.ILLEGAL_CONTENT]: 'inappropriate',
    };
    return map[reason] ?? 'other';
  }

  private mapToBusinessReason(reason: SafetyReportReason): string {
    const map: Record<string, string> = {
      [SafetyReportReason.SPAM]: 'spam',
      [SafetyReportReason.HARASSMENT]: 'inappropriate',
      [SafetyReportReason.HATE_OR_ABUSE]: 'inappropriate',
      [SafetyReportReason.THREATS]: 'inappropriate',
      [SafetyReportReason.SCAM_OR_FRAUD]: 'fraud_scam',
      [SafetyReportReason.SEXUAL_CONTENT]: 'inappropriate',
      [SafetyReportReason.VIOLENCE]: 'inappropriate',
      [SafetyReportReason.ILLEGAL_ACTIVITY]: 'inappropriate',
      [SafetyReportReason.MISINFORMATION]: 'incorrect_info',
      [SafetyReportReason.IMPERSONATION]: 'fraud_scam',
      [SafetyReportReason.PRIVACY_VIOLATION]: 'inappropriate',
      [SafetyReportReason.INAPPROPRIATE_CONTENT]: 'inappropriate',
      [SafetyReportReason.OTHER]: 'other',
      // Aliases
      [SafetyReportReason.FRAUD]: 'fraud_scam',
      [SafetyReportReason.INAPPROPRIATE]: 'inappropriate',
      [SafetyReportReason.MISLEADING]: 'incorrect_info',
      [SafetyReportReason.ILLEGAL_CONTENT]: 'inappropriate',
    };
    return map[reason] ?? 'other';
  }

  private mapToConversationReason(reason: SafetyReportReason): ConversationReportReason {
    const map: Record<string, ConversationReportReason> = {
      [SafetyReportReason.SPAM]: ConversationReportReason.SPAM,
      [SafetyReportReason.HARASSMENT]: ConversationReportReason.HARASSMENT,
      [SafetyReportReason.HATE_OR_ABUSE]: ConversationReportReason.HARASSMENT,
      [SafetyReportReason.THREATS]: ConversationReportReason.HARASSMENT,
      [SafetyReportReason.SCAM_OR_FRAUD]: ConversationReportReason.FRAUD,
      [SafetyReportReason.SEXUAL_CONTENT]: ConversationReportReason.INAPPROPRIATE,
      [SafetyReportReason.VIOLENCE]: ConversationReportReason.INAPPROPRIATE,
      [SafetyReportReason.ILLEGAL_ACTIVITY]: ConversationReportReason.INAPPROPRIATE,
      [SafetyReportReason.MISINFORMATION]: ConversationReportReason.OTHER,
      [SafetyReportReason.IMPERSONATION]: ConversationReportReason.FRAUD,
      [SafetyReportReason.PRIVACY_VIOLATION]: ConversationReportReason.HARASSMENT,
      [SafetyReportReason.INAPPROPRIATE_CONTENT]: ConversationReportReason.INAPPROPRIATE,
      [SafetyReportReason.OTHER]: ConversationReportReason.OTHER,
      // Aliases
      [SafetyReportReason.FRAUD]: ConversationReportReason.FRAUD,
      [SafetyReportReason.INAPPROPRIATE]: ConversationReportReason.INAPPROPRIATE,
      [SafetyReportReason.MISLEADING]: ConversationReportReason.OTHER,
      [SafetyReportReason.ILLEGAL_CONTENT]: ConversationReportReason.INAPPROPRIATE,
    };
    return map[reason] ?? ConversationReportReason.OTHER;
  }

  private async checkReportRateLimit(reporterId: string): Promise<void> {
    const key = `rate:safety:report:${reporterId}`;
    try {
      const current = await this.redisService.get(key);
      const count = current ? parseInt(current, 10) : 0;
      if (count >= this.maxReportsPerHour) {
        throw new HttpException(
          {
            statusCode: HttpStatus.TOO_MANY_REQUESTS,
            error: 'Too Many Requests',
            message:
              'Too many reports submitted. Please wait before reporting again.',
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    } catch (err: unknown) {
      if (err instanceof HttpException) throw err;
      this.logger.warn(`Safety report rate-limit check failed for reporter: [rate key]. Proceeding.`);
    }
  }

  private async incrementReportRateLimit(reporterId: string): Promise<void> {
    const key = `rate:safety:report:${reporterId}`;
    try {
      if (typeof this.redisService.incrementWithExpire === 'function') {
        await this.redisService.incrementWithExpire(key, this.reportRateLimitWindowSeconds);
      } else {
        await this.redisService.incr(key);
      }
    } catch {
      this.logger.warn('Safety rate-limit increment failed. Proceeding.');
    }
  }

  private async recordAuditLog(
    actorId: string,
    action: string,
    targetType: string,
    targetId: string,
    reportId?: string,
    reason?: string,
    metadata?: Record<string, any>,
  ): Promise<void> {
    try {
      const audit = this.auditLogRepo.create({
        actorId,
        action,
        targetType,
        targetId,
        reportId: reportId ?? null,
        reason: reason ?? null,
        metadata: metadata ?? null,
      });
      await this.auditLogRepo.save(audit);
    } catch (err) {
      this.logger.warn(`Failed to record moderation audit log: ${err}`);
    }
  }

  private successMessage(): string {
    return 'Thank you for helping keep Aaspaas safe. Our moderation team will review this report.';
  }
}

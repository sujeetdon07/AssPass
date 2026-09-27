import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { User } from '../users/entities/user.entity.js';
import { SafetyReport } from '../safety/entities/safety-report.entity.js';
import { ModerationAuditLog } from '../safety/entities/moderation-audit-log.entity.js';
import { Post } from '../feed/entities/post.entity.js';
import { Comment } from '../feed/entities/comment.entity.js';
import { MarketplaceListing } from '../marketplace/entities/marketplace-listing.entity.js';
import { Business } from '../businesses/entities/business.entity.js';
import { ServiceListing } from '../services/entities/service-listing.entity.js';
import { Community } from '../communities/entities/community.entity.js';
import { AuthModule } from '../auth/auth.module.js';

import { AdminService } from './admin.service.js';
import { AdminController } from './admin.controller.js';

/**
 * AdminModule — Phase 11 Admin Dashboard backend.
 *
 * Exposes authenticated, role-guarded REST endpoints under /api/v1/admin.
 * MODERATOR and ADMIN roles are enforced per-route.
 * Every privileged mutation is logged to moderation_audit_logs.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      SafetyReport,
      ModerationAuditLog,
      Post,
      Comment,
      MarketplaceListing,
      Business,
      ServiceListing,
      Community,
    ]),
    AuthModule,
  ],
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService],
})
export class AdminModule {}

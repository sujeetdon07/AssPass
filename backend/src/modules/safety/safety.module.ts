import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

// Safety Entities
import { SafetyReport } from './entities/safety-report.entity.js';
import { ModerationAuditLog } from './entities/moderation-audit-log.entity.js';

// Cross-module entity imports (Safety reads from and coordinates across domains)
import { UserBlock } from '../messaging/entities/user-block.entity.js';
import { User } from '../users/entities/user.entity.js';
import { Report } from '../feed/entities/report.entity.js';
import { Post } from '../feed/entities/post.entity.js';
import { Comment } from '../feed/entities/comment.entity.js';
import { MarketplaceReport } from '../marketplace/entities/marketplace-report.entity.js';
import { MarketplaceListing } from '../marketplace/entities/marketplace-listing.entity.js';
import { BusinessReport } from '../businesses/entities/business-report.entity.js';
import { Business } from '../businesses/entities/business.entity.js';
import { ServiceReport } from '../services/entities/service-report.entity.js';
import { ServiceListing } from '../services/entities/service-listing.entity.js';
import { Conversation } from '../messaging/entities/conversation.entity.js';
import { Message } from '../messaging/entities/message.entity.js';
import { ConversationReport } from '../messaging/entities/conversation-report.entity.js';
import { Event } from '../events/entities/event.entity.js';

import { AuthModule } from '../auth/auth.module.js';
import { SafetyService } from './safety.service.js';
import { SafetyController } from './safety.controller.js';

/**
 * SafetyModule — Phase 10 Trust & Safety foundation.
 *
 * Centralizes trust & safety, content reporting, user blocking,
 * report history, moderation status lifecycle, and audit logs.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([
      SafetyReport,
      ModerationAuditLog,
      UserBlock,
      User,
      Report,
      Post,
      Comment,
      MarketplaceReport,
      MarketplaceListing,
      BusinessReport,
      Business,
      ServiceReport,
      ServiceListing,
      Conversation,
      Message,
      ConversationReport,
      Event,
    ]),
    AuthModule,
  ],
  controllers: [SafetyController],
  providers: [SafetyService],
  exports: [SafetyService],
})
export class SafetyModule {}

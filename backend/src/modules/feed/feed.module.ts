import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Post } from './entities/post.entity.js';
import { PostReaction } from './entities/post-reaction.entity.js';
import { Comment } from './entities/comment.entity.js';
import { Report } from './entities/report.entity.js';
import { User } from '../users/entities/user.entity.js';
import { AuthModule } from '../auth/auth.module.js';
import { FeedController } from './feed.controller.js';
import { FeedService } from './services/feed.service.js';
import { ReactionsService } from './services/reactions.service.js';
import { CommentsService } from './services/comments.service.js';
import { ReportsService } from './services/reports.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Post, PostReaction, Comment, Report, User]),
    AuthModule,
  ],
  controllers: [FeedController],
  providers: [
    FeedService,
    ReactionsService,
    CommentsService,
    ReportsService,
  ],
  exports: [
    FeedService,
    ReactionsService,
    CommentsService,
    ReportsService,
  ],
})
export class FeedModule {}

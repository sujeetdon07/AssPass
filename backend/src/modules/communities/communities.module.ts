import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Community } from './entities/community.entity.js';
import { CommunityMember } from './entities/community-member.entity.js';
import { Post } from '../feed/entities/post.entity.js';
import { User } from '../users/entities/user.entity.js';
import { Report } from '../feed/entities/report.entity.js';
import { CommunitiesService } from './services/communities.service.js';
import { CommunitiesController } from './communities.controller.js';
import { RedisModule } from '../../database/redis.module.js';
import { AuthModule } from '../auth/auth.module.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Community,
      CommunityMember,
      Post,
      User,
      Report,
    ]),
    RedisModule,
    AuthModule,
  ],
  controllers: [CommunitiesController],
  providers: [CommunitiesService],
  exports: [CommunitiesService],
})
export class CommunitiesModule {}

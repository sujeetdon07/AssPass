import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Post } from '../feed/entities/post.entity.js';
import { User } from '../users/entities/user.entity.js';
import { RedisModule } from '../../database/redis.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { NearbyService } from './services/nearby.service.js';
import { NearbyController } from './nearby.controller.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Post, User]),
    RedisModule,
    AuthModule,
  ],
  controllers: [NearbyController],
  providers: [NearbyService],
  exports: [NearbyService],
})
export class NearbyModule {}

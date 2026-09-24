import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ServiceListing } from './entities/service-listing.entity.js';
import { ServiceFavorite } from './entities/service-favorite.entity.js';
import { ServiceReport } from './entities/service-report.entity.js';
import { User } from '../users/entities/user.entity.js';
import { RedisModule } from '../../database/redis.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { ServicesService } from './services/services.service.js';
import { ServicesController } from './services.controller.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ServiceListing,
      ServiceFavorite,
      ServiceReport,
      User,
    ]),
    RedisModule,
    AuthModule,
  ],
  controllers: [ServicesController],
  providers: [ServicesService],
  exports: [ServicesService],
})
export class ServicesModule {}

import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Business } from './entities/business.entity.js';
import { BusinessImage } from './entities/business-image.entity.js';
import { BusinessService } from './entities/business-service.entity.js';
import { BusinessFavorite } from './entities/business-favorite.entity.js';
import { BusinessReport } from './entities/business-report.entity.js';
import { User } from '../users/entities/user.entity.js';
import { RedisModule } from '../../database/redis.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { BusinessesService } from './services/businesses.service.js';
import { BusinessesController } from './businesses.controller.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Business,
      BusinessImage,
      BusinessService,
      BusinessFavorite,
      BusinessReport,
      User,
    ]),
    RedisModule,
    AuthModule,
  ],
  controllers: [BusinessesController],
  providers: [BusinessesService],
  exports: [BusinessesService],
})
export class BusinessesModule {}

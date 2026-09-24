import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MarketplaceListing } from './entities/marketplace-listing.entity.js';
import { MarketplaceListingImage } from './entities/marketplace-listing-image.entity.js';
import { MarketplaceFavorite } from './entities/marketplace-favorite.entity.js';
import { MarketplaceReport } from './entities/marketplace-report.entity.js';
import { User } from '../users/entities/user.entity.js';
import { RedisModule } from '../../database/redis.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { MarketplaceService } from './services/marketplace.service.js';
import { MarketplaceController } from './marketplace.controller.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      MarketplaceListing,
      MarketplaceListingImage,
      MarketplaceFavorite,
      MarketplaceReport,
      User,
    ]),
    RedisModule,
    AuthModule,
  ],
  controllers: [MarketplaceController],
  providers: [MarketplaceService],
  exports: [MarketplaceService],
})
export class MarketplaceModule {}

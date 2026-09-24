import { IsEnum, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { MarketplaceListingStatus } from '../entities/marketplace-listing.entity.js';

export class UpdateListingStatusDto {
  @ApiProperty({
    enum: MarketplaceListingStatus,
    example: MarketplaceListingStatus.SOLD,
    description: 'New listing lifecycle status (active, sold, archived)',
  })
  @IsNotEmpty()
  @IsEnum(MarketplaceListingStatus, {
    message: 'Invalid status. Must be active, sold, or archived.',
  })
  status!: MarketplaceListingStatus;
}

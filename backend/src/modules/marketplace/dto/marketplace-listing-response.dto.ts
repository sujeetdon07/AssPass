import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  MarketplaceCategory,
  MarketplaceCondition,
  MarketplaceListingStatus,
} from '../entities/marketplace-listing.entity.js';

export class SellerSummaryDto {
  @ApiProperty({ description: 'Seller user ID' })
  id!: string;

  @ApiPropertyOptional({ description: 'Display name' })
  displayName!: string | null;

  @ApiPropertyOptional({ description: 'Avatar image URL' })
  avatarUrl!: string | null;

  @ApiPropertyOptional({ description: 'Locality name' })
  locality!: string | null;

  @ApiPropertyOptional({ description: 'City name' })
  city!: string | null;
}

export class ListingImageResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  url!: string;

  @ApiProperty({ default: 0 })
  displayOrder!: number;
}

export class MarketplaceListingResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  sellerId!: string;

  @ApiProperty({ type: SellerSummaryDto })
  seller!: SellerSummaryDto;

  @ApiProperty()
  title!: string;

  @ApiProperty()
  description!: string;

  @ApiProperty({ enum: MarketplaceCategory })
  category!: MarketplaceCategory;

  @ApiProperty({ example: 4500 })
  price!: number;

  @ApiProperty({ default: 'INR' })
  currency!: string;

  @ApiProperty({ enum: MarketplaceCondition })
  condition!: MarketplaceCondition;

  @ApiProperty({ enum: MarketplaceListingStatus })
  status!: MarketplaceListingStatus;

  @ApiProperty({ default: 'IN' })
  countryCode!: string;

  @ApiPropertyOptional()
  state?: string | null;

  @ApiPropertyOptional()
  district?: string | null;

  @ApiPropertyOptional()
  city?: string | null;

  @ApiPropertyOptional()
  locality?: string | null;

  @ApiPropertyOptional()
  neighborhood?: string | null;

  @ApiProperty({ default: 0 })
  favoriteCount!: number;

  @ApiProperty({ default: false })
  isFavorited!: boolean;

  @ApiProperty({ default: false })
  isOwner!: boolean;

  @ApiProperty({ type: [ListingImageResponseDto] })
  images!: ListingImageResponseDto[];

  @ApiPropertyOptional({
    description: 'Privacy-safe distance text (e.g. "Nearby", "500 m away", "1.5 km away")',
    example: '1.5 km away',
  })
  distance?: string | null;

  @ApiPropertyOptional({
    description: 'Privacy-safe rounded distance band in meters',
    example: 1500,
  })
  distanceMeters?: number | null;

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;
}

export class PaginatedMarketplaceListingsResponseDto {
  @ApiProperty({ type: [MarketplaceListingResponseDto] })
  items!: MarketplaceListingResponseDto[];

  @ApiPropertyOptional({ description: 'Opaque cursor token for next page' })
  nextCursor?: string | null;

  @ApiProperty({ description: 'Whether there are more items to fetch' })
  hasMore!: boolean;
}

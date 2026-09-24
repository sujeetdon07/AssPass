import {
  IsOptional,
  IsString,
  IsEnum,
  IsNumber,
  Min,
  Max,
  IsLatitude,
  IsLongitude,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  MarketplaceCategory,
  MarketplaceCondition,
  MarketplaceListingStatus,
} from '../entities/marketplace-listing.entity.js';

export enum MarketplaceSortBy {
  NEWEST = 'newest',
  PRICE_ASC = 'price_asc',
  PRICE_DESC = 'price_desc',
  NEAREST = 'nearest',
}

export class GetListingsQueryDto {
  @ApiPropertyOptional({ description: 'Search term for title and description' })
  @IsOptional()
  @IsString()
  query?: string;

  @ApiPropertyOptional({ enum: MarketplaceCategory, description: 'Filter by category' })
  @IsOptional()
  @IsEnum(MarketplaceCategory)
  category?: MarketplaceCategory;

  @ApiPropertyOptional({ enum: MarketplaceCondition, description: 'Filter by condition' })
  @IsOptional()
  @IsEnum(MarketplaceCondition)
  condition?: MarketplaceCondition;

  @ApiPropertyOptional({ description: 'Minimum price filter', example: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  minPrice?: number;

  @ApiPropertyOptional({ description: 'Maximum price filter', example: 10000 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  maxPrice?: number;

  @ApiPropertyOptional({ description: 'Filter by locality name' })
  @IsOptional()
  @IsString()
  locality?: string;

  @ApiPropertyOptional({ description: 'Filter by city name' })
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional({
    enum: MarketplaceListingStatus,
    description: 'Filter by listing status (defaults to active in discovery)',
  })
  @IsOptional()
  @IsEnum(MarketplaceListingStatus)
  status?: MarketplaceListingStatus;

  @ApiPropertyOptional({
    description: 'Radius in kilometers for spatial discovery (1–50 km)',
    example: 5,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(50)
  radius?: number;

  @ApiPropertyOptional({ description: 'Current latitude for radius/nearest discovery' })
  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional({ description: 'Current longitude for radius/nearest discovery' })
  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  longitude?: number;

  @ApiPropertyOptional({
    enum: MarketplaceSortBy,
    default: MarketplaceSortBy.NEWEST,
    description: 'Sort ordering',
  })
  @IsOptional()
  @IsEnum(MarketplaceSortBy)
  sortBy?: MarketplaceSortBy = MarketplaceSortBy.NEWEST;

  @ApiPropertyOptional({ description: 'Opaque cursor for pagination' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ description: 'Page limit (1–50)', default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(50)
  limit: number = 20;
}

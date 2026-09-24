import {
  IsString,
  MinLength,
  MaxLength,
  IsEnum,
  IsOptional,
  IsNumber,
  Min,
  Max,
  IsArray,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  MarketplaceCategory,
  MarketplaceCondition,
} from '../entities/marketplace-listing.entity.js';
import { ListingImageDto } from './create-listing.dto.js';

export class UpdateListingDto {
  @ApiPropertyOptional({
    example: 'Solid Sheesham Wood Study Table (Revised)',
    description: 'Updated title (5–120 characters)',
  })
  @IsOptional()
  @IsString()
  @MinLength(5, { message: 'Title must be at least 5 characters.' })
  @MaxLength(120, { message: 'Title must not exceed 120 characters.' })
  title?: string;

  @ApiPropertyOptional({
    example: 'Updated description for study table.',
    description: 'Updated description (10–5000 characters)',
  })
  @IsOptional()
  @IsString()
  @MinLength(10, { message: 'Description must be at least 10 characters.' })
  @MaxLength(5000, { message: 'Description must not exceed 5000 characters.' })
  description?: string;

  @ApiPropertyOptional({
    enum: MarketplaceCategory,
    example: MarketplaceCategory.FURNITURE,
  })
  @IsOptional()
  @IsEnum(MarketplaceCategory, {
    message: 'Invalid category. Must be an approved marketplace category.',
  })
  category?: MarketplaceCategory;

  @ApiPropertyOptional({
    example: 4000,
    description: 'Updated price in currency units',
  })
  @IsOptional()
  @IsNumber({}, { message: 'Price must be a valid number.' })
  @Min(0, { message: 'Price cannot be negative.' })
  @Max(100000000, { message: 'Price exceeds maximum allowed limit.' })
  price?: number;

  @ApiPropertyOptional({
    enum: MarketplaceCondition,
    example: MarketplaceCondition.GOOD,
  })
  @IsOptional()
  @IsEnum(MarketplaceCondition, {
    message: 'Invalid condition.',
  })
  condition?: MarketplaceCondition;

  @ApiPropertyOptional({ example: 'Karnataka' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  state?: string;

  @ApiPropertyOptional({ example: 'Bengaluru' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @ApiPropertyOptional({ example: 'Indiranagar' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  locality?: string;

  @ApiPropertyOptional({ example: 'Defence Colony' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  neighborhood?: string;

  @ApiPropertyOptional({
    type: [ListingImageDto],
    description: 'Updated media/images for the listing',
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ListingImageDto)
  images?: ListingImageDto[];
}

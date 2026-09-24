import {
  IsString,
  IsNotEmpty,
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
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  MarketplaceCategory,
  MarketplaceCondition,
} from '../entities/marketplace-listing.entity.js';

export class ListingImageDto {
  @ApiProperty({ example: 'https://images.example.com/item1.jpg', description: 'URL of the listing image' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  url!: string;

  @ApiPropertyOptional({ example: 0, description: 'Display order of the image' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  displayOrder?: number;
}

export class CreateListingDto {
  @ApiProperty({
    example: 'Solid Sheesham Wood Study Table',
    description: 'Title of the listing (5–120 characters)',
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(5, { message: 'Title must be at least 5 characters.' })
  @MaxLength(120, { message: 'Title must not exceed 120 characters.' })
  title!: string;

  @ApiProperty({
    example: 'Handcrafted solid wood study table with 2 drawers. Excellent condition, 1.5 years old.',
    description: 'Detailed description (10–5000 characters)',
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(10, { message: 'Description must be at least 10 characters.' })
  @MaxLength(5000, { message: 'Description must not exceed 5000 characters.' })
  description!: string;

  @ApiProperty({
    enum: MarketplaceCategory,
    example: MarketplaceCategory.FURNITURE,
    description: 'Listing category',
  })
  @IsEnum(MarketplaceCategory, {
    message: 'Invalid category. Must be an approved marketplace category.',
  })
  category!: MarketplaceCategory;

  @ApiProperty({
    example: 4500,
    description: 'Price in currency units (>= 0; 0 denotes Free / Giveaway)',
  })
  @IsNumber({}, { message: 'Price must be a valid number.' })
  @Min(0, { message: 'Price cannot be negative.' })
  @Max(100000000, { message: 'Price exceeds maximum allowed limit.' })
  price!: number;

  @ApiPropertyOptional({ example: 'INR', default: 'INR' })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  currency?: string;

  @ApiProperty({
    enum: MarketplaceCondition,
    example: MarketplaceCondition.LIKE_NEW,
    description: 'Condition of the item',
  })
  @IsEnum(MarketplaceCondition, {
    message: 'Invalid condition. Must be new, like_new, good, fair, or used.',
  })
  condition!: MarketplaceCondition;

  @ApiPropertyOptional({ example: 'IN', default: 'IN' })
  @IsOptional()
  @IsString()
  @MaxLength(5)
  countryCode?: string;

  @ApiPropertyOptional({ example: 'Karnataka' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  state?: string;

  @ApiPropertyOptional({ example: 'Bengaluru Urban' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  district?: string;

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
    description: 'Optional media/images for the listing',
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ListingImageDto)
  images?: ListingImageDto[];
}

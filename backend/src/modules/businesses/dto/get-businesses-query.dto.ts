import {
  IsString,
  IsOptional,
  IsEnum,
  IsNumber,
  Min,
  Max,
  IsBoolean,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { BusinessCategory, BusinessStatus } from '../entities/business.entity.js';

export enum BusinessSortBy {
  RELEVANCE = 'relevance',
  NEWEST = 'newest',
  NEAREST = 'nearest',
}

export class GetBusinessesQueryDto {
  @ApiPropertyOptional({ description: 'Text search query matching name, category or description' })
  @IsOptional()
  @IsString()
  query?: string;

  @ApiPropertyOptional({ enum: BusinessCategory, description: 'Filter by category' })
  @IsOptional()
  @IsEnum(BusinessCategory)
  category?: BusinessCategory;

  @ApiPropertyOptional({ description: 'Filter by locality name' })
  @IsOptional()
  @IsString()
  locality?: string;

  @ApiPropertyOptional({ description: 'Filter by city name' })
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional({ description: 'User latitude for PostGIS radius search', example: 12.9784 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiPropertyOptional({ description: 'User longitude for PostGIS radius search', example: 77.6408 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @ApiPropertyOptional({ description: 'Radius in kilometers (e.g., 1, 3, 5, 10, 20)', example: 5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.5)
  @Max(100)
  radius?: number;

  @ApiPropertyOptional({ description: 'Filter only businesses currently open', example: false })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true || value === '1' || value === 1)
  @IsBoolean()
  openNow?: boolean;

  @ApiPropertyOptional({ enum: BusinessSortBy, default: BusinessSortBy.NEWEST })
  @IsOptional()
  @IsEnum(BusinessSortBy)
  sortBy?: BusinessSortBy = BusinessSortBy.NEWEST;

  @ApiPropertyOptional({ enum: BusinessStatus, default: BusinessStatus.ACTIVE })
  @IsOptional()
  @IsEnum(BusinessStatus)
  status?: BusinessStatus;

  @ApiPropertyOptional({ description: 'Opaque pagination cursor' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ description: 'Number of results to return (max 50)', default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(50)
  limit?: number = 20;
}

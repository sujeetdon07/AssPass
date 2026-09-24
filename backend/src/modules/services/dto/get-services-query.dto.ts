import {
  IsString,
  IsOptional,
  IsEnum,
  IsNumber,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { ServiceCategory, ServiceStatus } from '../entities/service-listing.entity.js';

export enum ServiceSortBy {
  RELEVANCE = 'relevance',
  NEWEST = 'newest',
  NEAREST = 'nearest',
}

export class GetServicesQueryDto {
  @ApiPropertyOptional({ description: 'Text search query matching service title, category, or description' })
  @IsOptional()
  @IsString()
  query?: string;

  @ApiPropertyOptional({ enum: ServiceCategory, description: 'Filter by category' })
  @IsOptional()
  @IsEnum(ServiceCategory)
  category?: ServiceCategory;

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

  @ApiPropertyOptional({ enum: ServiceSortBy, default: ServiceSortBy.NEWEST })
  @IsOptional()
  @IsEnum(ServiceSortBy)
  sortBy?: ServiceSortBy = ServiceSortBy.NEWEST;

  @ApiPropertyOptional({ enum: ServiceStatus, default: ServiceStatus.ACTIVE })
  @IsOptional()
  @IsEnum(ServiceStatus)
  status?: ServiceStatus;

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

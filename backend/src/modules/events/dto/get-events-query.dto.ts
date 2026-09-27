import {
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { EventCategory, EventStatus } from '../entities/event.entity.js';

export enum EventTimeFrame {
  UPCOMING = 'upcoming',
  PAST = 'past',
  ALL = 'all',
}

export class GetEventsQueryDto {
  @ApiPropertyOptional({
    description: 'Filter by locality name',
    example: 'Indiranagar',
  })
  @IsOptional()
  @IsString()
  locality?: string;

  @ApiPropertyOptional({
    description: 'Filter by community UUID',
    example: 'c3d550e2-66b2-4d22-bf02-9443adbb3832',
  })
  @IsOptional()
  @IsUUID('4')
  communityId?: string;

  @ApiPropertyOptional({
    enum: EventCategory,
    description: 'Filter by category',
  })
  @IsOptional()
  @IsEnum(EventCategory)
  category?: EventCategory;

  @ApiPropertyOptional({
    enum: EventStatus,
    description: 'Filter by status (default: active)',
    default: EventStatus.ACTIVE,
  })
  @IsOptional()
  @IsEnum(EventStatus)
  status?: EventStatus;

  @ApiPropertyOptional({
    enum: EventTimeFrame,
    description: 'Timeframe filter (upcoming, past, all). Default: upcoming',
    default: EventTimeFrame.UPCOMING,
  })
  @IsOptional()
  @IsEnum(EventTimeFrame)
  timeFrame?: EventTimeFrame;

  @ApiPropertyOptional({
    enum: EventTimeFrame,
    description: 'Alias for timeFrame (upcoming, past, all)',
  })
  @IsOptional()
  @IsEnum(EventTimeFrame)
  timeframe?: EventTimeFrame;

  @ApiPropertyOptional({
    description: 'Search in title, description, or venue',
    example: 'coffee',
  })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({
    description: 'Latitude for geographic radius discovery',
    example: 12.9784,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiPropertyOptional({
    description: 'Longitude for geographic radius discovery',
    example: 77.6408,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @ApiPropertyOptional({
    description: 'Radius in kilometers (1 to 50, default 10)',
    example: 10,
    default: 10,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(50)
  radiusKm?: number = 10;

  @ApiPropertyOptional({
    description: 'Pagination limit (1 to 50, default 20)',
    example: 20,
    default: 20,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = 20;

  @ApiPropertyOptional({
    description: 'Opaque cursor for pagination',
  })
  @IsOptional()
  @IsString()
  cursor?: string;
}

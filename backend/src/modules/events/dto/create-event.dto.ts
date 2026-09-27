import {
  IsEnum,
  IsISO8601,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { EventCategory } from '../entities/event.entity.js';

export class CreateEventDto {
  @ApiProperty({
    description: 'Title of the event',
    example: 'Indiranagar Weekend Board Games & Coffee',
    minLength: 3,
    maxLength: 150,
  })
  @IsString()
  @IsNotEmpty({ message: 'Title is required.' })
  @MinLength(3, { message: 'Title must be at least 3 characters.' })
  @MaxLength(150, { message: 'Title must not exceed 150 characters.' })
  title!: string;

  @ApiProperty({
    description: 'Detailed description of the event, rules, what to bring, etc.',
    example: 'Join fellow neighbors for a fun afternoon of Catan, Ticket to Ride, and fresh filter coffee!',
    minLength: 10,
    maxLength: 5000,
  })
  @IsString()
  @IsNotEmpty({ message: 'Description is required.' })
  @MinLength(10, { message: 'Description must be at least 10 characters.' })
  @MaxLength(5000, { message: 'Description must not exceed 5000 characters.' })
  description!: string;

  @ApiProperty({
    enum: EventCategory,
    description: 'Category of the event',
    example: EventCategory.SOCIAL,
  })
  @IsEnum(EventCategory, { message: 'Invalid event category.' })
  category!: EventCategory;

  @ApiProperty({
    description: 'Start date and time (ISO 8601 string)',
    example: '2026-10-15T10:00:00.000Z',
  })
  @IsISO8601({}, { message: 'Start time must be a valid ISO 8601 date string.' })
  startAt!: string;

  @ApiProperty({
    description: 'End date and time (ISO 8601 string)',
    example: '2026-10-15T14:00:00.000Z',
  })
  @IsISO8601({}, { message: 'End time must be a valid ISO 8601 date string.' })
  endAt!: string;

  @ApiPropertyOptional({
    description: 'Timezone identifier',
    default: 'Asia/Kolkata',
  })
  @IsOptional()
  @IsString()
  timezone?: string;

  @ApiProperty({
    description: 'Name of the venue or place',
    example: 'Clubhouse, Palm Meadows',
  })
  @IsString()
  @IsNotEmpty({ message: 'Venue is required.' })
  @MinLength(2, { message: 'Venue name must be at least 2 characters.' })
  @MaxLength(200, { message: 'Venue name must not exceed 200 characters.' })
  venue!: string;

  @ApiProperty({
    description: 'Street address / directions',
    example: 'Near 12th Main Road, Indiranagar',
  })
  @IsString()
  @IsNotEmpty({ message: 'Address is required.' })
  @MinLength(5, { message: 'Address must be at least 5 characters.' })
  @MaxLength(500, { message: 'Address must not exceed 500 characters.' })
  address!: string;

  @ApiPropertyOptional({
    description: 'Neighborhood or locality name',
    example: 'Indiranagar',
  })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  locality?: string;

  @ApiPropertyOptional({
    description: 'City name',
    example: 'Bengaluru',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @ApiPropertyOptional({
    description: 'State name',
    example: 'Karnataka',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  state?: string;

  @ApiPropertyOptional({
    description: 'Latitude of the venue (-90 to 90)',
    example: 12.9784,
  })
  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiPropertyOptional({
    description: 'Longitude of the venue (-180 to 180)',
    example: 77.6408,
  })
  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @ApiPropertyOptional({
    description: 'Optional Community UUID if event is scoped to a specific community',
    example: 'c3d550e2-66b2-4d22-bf02-9443adbb3832',
  })
  @IsOptional()
  @IsUUID('4', { message: 'Community ID must be a valid UUID.' })
  communityId?: string;

  @ApiPropertyOptional({
    description: 'Cover image URL for the event banner',
    example: 'https://images.unsplash.com/photo-1511578314322-379afb476865',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverImageUrl?: string;
}

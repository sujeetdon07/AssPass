import { IsNumber, IsOptional, Min, Max, IsEnum, IsString } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PostCategory } from '../../feed/entities/post.entity.js';

export const ALLOWED_RADIUS_KM = [1, 3, 5, 10, 20];
export const DEFAULT_RADIUS_KM = 5;
export const MAX_RADIUS_KM = 20;

export class GetNearbyPostsDto {
  @ApiProperty({
    description: 'Current latitude (-90 to 90)',
    example: 12.9784,
  })
  @Type(() => Number)
  @IsNumber({}, { message: 'Latitude must be a valid number' })
  @Min(-90, { message: 'Latitude must be between -90 and 90' })
  @Max(90, { message: 'Latitude must be between -90 and 90' })
  latitude!: number;

  @ApiProperty({
    description: 'Current longitude (-180 to 180)',
    example: 77.6408,
  })
  @Type(() => Number)
  @IsNumber({}, { message: 'Longitude must be a valid number' })
  @Min(-180, { message: 'Longitude must be between -180 and 180' })
  @Max(180, { message: 'Longitude must be between -180 and 180' })
  longitude!: number;

  @ApiPropertyOptional({
    description: 'Discovery radius in kilometers (1, 3, 5, 10, 20). Default: 5 km',
    example: 5,
    default: 5,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({}, { message: 'Radius must be a valid number' })
  @Min(1, { message: 'Radius must be at least 1 km' })
  @Max(MAX_RADIUS_KM, { message: `Radius cannot exceed ${MAX_RADIUS_KM} km` })
  radius?: number = DEFAULT_RADIUS_KM;

  @ApiPropertyOptional({
    description: 'Filter posts by category',
    enum: PostCategory,
  })
  @IsOptional()
  @IsEnum(PostCategory)
  category?: PostCategory;

  @ApiPropertyOptional({
    description: 'Number of posts to return per page (1 to 50). Default: 20',
    default: 20,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(50)
  limit?: number = 20;

  @ApiPropertyOptional({
    description: 'Deterministic pagination cursor for infinite scrolling',
  })
  @IsOptional()
  @IsString()
  cursor?: string;
}

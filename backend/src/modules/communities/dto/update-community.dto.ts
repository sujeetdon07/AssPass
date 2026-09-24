import {
  IsString,
  MinLength,
  MaxLength,
  IsEnum,
  IsOptional,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  CommunityCategory,
  CommunityVisibility,
  CommunityStatus,
} from '../entities/community.entity.js';

export class UpdateCommunityDto {
  @ApiPropertyOptional({
    enum: CommunityStatus,
    description: 'Updated status of the community (active or archived)',
  })
  @IsOptional()
  @IsEnum(CommunityStatus, {
    message: 'Status must be active, suspended, or archived.',
  })
  status?: CommunityStatus;
  @ApiPropertyOptional({
    example: 'Indiranagar Resident Club',
    description: 'Updated name of the community',
  })
  @IsOptional()
  @IsString()
  @MinLength(3, { message: 'Community name must be at least 3 characters.' })
  @MaxLength(100, { message: 'Community name must not exceed 100 characters.' })
  name?: string;

  @ApiPropertyOptional({
    example: 'Updated description for the community.',
    description: 'Updated description of the community',
  })
  @IsOptional()
  @IsString()
  @MinLength(10, { message: 'Description must be at least 10 characters.' })
  @MaxLength(1000, { message: 'Description must not exceed 1000 characters.' })
  description?: string;

  @ApiPropertyOptional({
    enum: CommunityCategory,
    description: 'Updated category of the community',
  })
  @IsOptional()
  @IsEnum(CommunityCategory, {
    message: 'Invalid category. Must be an approved community category.',
  })
  category?: CommunityCategory;

  @ApiPropertyOptional({
    enum: CommunityVisibility,
    description: 'Updated visibility',
  })
  @IsOptional()
  @IsEnum(CommunityVisibility, {
    message: 'Visibility must be either public or private.',
  })
  visibility?: CommunityVisibility;

  @ApiPropertyOptional({ example: 'https://example.com/cover.jpg' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverImageUrl?: string;

  @ApiPropertyOptional({ example: 'https://example.com/avatar.jpg' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatarUrl?: string;
}

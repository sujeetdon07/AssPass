import {
  IsString,
  IsNotEmpty,
  MinLength,
  MaxLength,
  IsEnum,
  IsOptional,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  CommunityCategory,
  CommunityVisibility,
} from '../entities/community.entity.js';

export class CreateCommunityDto {
  @ApiProperty({
    example: 'Indiranagar Resident Club',
    description: 'Name of the community',
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(3, { message: 'Community name must be at least 3 characters.' })
  @MaxLength(100, { message: 'Community name must not exceed 100 characters.' })
  name!: string;

  @ApiProperty({
    example: 'A vibrant community of residents in Indiranagar, Bengaluru.',
    description: 'Description of the community and its purpose',
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(10, { message: 'Description must be at least 10 characters.' })
  @MaxLength(1000, { message: 'Description must not exceed 1000 characters.' })
  description!: string;

  @ApiProperty({
    enum: CommunityCategory,
    example: CommunityCategory.NEIGHBORHOOD,
    description: 'Category of the community',
  })
  @IsEnum(CommunityCategory, {
    message: 'Invalid category. Must be an approved community category.',
  })
  category!: CommunityCategory;

  @ApiPropertyOptional({
    enum: CommunityVisibility,
    example: CommunityVisibility.PUBLIC,
    default: CommunityVisibility.PUBLIC,
  })
  @IsOptional()
  @IsEnum(CommunityVisibility, {
    message: 'Visibility must be either public or private.',
  })
  visibility?: CommunityVisibility;

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

import {
  IsOptional,
  IsString,
  IsEnum,
  IsInt,
  IsBoolean,
  Min,
  Max,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  CommunityCategory,
  CommunityVisibility,
} from '../entities/community.entity.js';

export enum CommunityDiscoveryScope {
  ALL = 'all',
  JOINED = 'joined',
  LOCAL = 'local',
}

export class GetCommunitiesQueryDto {
  @ApiPropertyOptional({
    description: 'Search query for community name, description, or slug',
  })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({
    enum: CommunityCategory,
    description: 'Filter by community category',
  })
  @IsOptional()
  @IsEnum(CommunityCategory)
  category?: CommunityCategory;

  @ApiPropertyOptional({
    enum: CommunityVisibility,
    description: 'Filter by visibility',
  })
  @IsOptional()
  @IsEnum(CommunityVisibility)
  visibility?: CommunityVisibility;

  @ApiPropertyOptional({
    enum: CommunityDiscoveryScope,
    default: CommunityDiscoveryScope.ALL,
    description: 'Scope: all, joined, or local',
  })
  @IsOptional()
  @IsEnum(CommunityDiscoveryScope)
  scope?: CommunityDiscoveryScope = CommunityDiscoveryScope.ALL;

  @ApiPropertyOptional({
    description: 'Filter by joined communities only',
  })
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  joinedOnly?: boolean;

  @ApiPropertyOptional({
    description: 'Filter by city',
  })
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional({
    description: 'Filter by locality',
  })
  @IsOptional()
  @IsString()
  locality?: string;

  @ApiPropertyOptional({
    description: 'Cursor token for pagination',
  })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({
    default: 20,
    minimum: 1,
    maximum: 50,
    description: 'Number of communities to return per page',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = 20;
}

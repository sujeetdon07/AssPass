import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PostCategory } from '../entities/post.entity.js';

export enum FeedScope {
  LOCAL = 'local',
  ALL = 'all',
}

export class GetFeedQueryDto {
  @ApiPropertyOptional({
    description: 'Number of posts to return (1 to 50). Default is 20.',
    default: 20,
    minimum: 1,
    maximum: 50,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit: number = 20;

  @ApiPropertyOptional({
    description: 'Pagination cursor from previous page.',
    example: 'MjAyNi0wOS0yMlQxMTo1MDowMC4wMDBaLGJkNzE1OTAtMjE2Zi00ZTRmLWJiMTgtMWZiNDY1ZGQzMDEy',
  })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({
    enum: PostCategory,
    description: 'Filter posts by specific category.',
  })
  @IsOptional()
  @IsEnum(PostCategory)
  category?: PostCategory;

  @ApiPropertyOptional({
    enum: FeedScope,
    default: FeedScope.LOCAL,
    description: 'Filter scope: "local" (user locality/city) or "all" (broader community).',
  })
  @IsOptional()
  @IsEnum(FeedScope)
  scope: FeedScope = FeedScope.LOCAL;
}

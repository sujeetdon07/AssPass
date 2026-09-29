import {
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  IsArray,
  ArrayMaxSize,
  ValidateNested,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PostCategory } from '../entities/post.entity.js';
import { CreatePostMentionDto } from './create-post-mention.dto.js';
import { CreatePostImageDto } from './create-post-image.dto.js';

export class CreatePostDto {
  @ApiProperty({
    description: 'Post text content (1 to 5000 characters).',
    example: 'Power cut scheduled in HAL 2nd Stage tomorrow from 10 AM to 2 PM.',
  })
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @IsNotEmpty({ message: 'Post content cannot be empty.' })
  @MinLength(1, { message: 'Post content must contain at least 1 character.' })
  @MaxLength(5000, { message: 'Post content cannot exceed 5000 characters.' })
  content!: string;

  @ApiPropertyOptional({
    enum: PostCategory,
    default: PostCategory.GENERAL,
    description: 'Post category.',
    example: PostCategory.ALERT,
  })
  @IsOptional()
  @IsEnum(PostCategory, { message: 'Invalid post category.' })
  category?: PostCategory;

  @ApiPropertyOptional({
    type: [CreatePostMentionDto],
    description: 'Structured @mentions with immutable userId, start, and length.',
  })
  @IsOptional()
  @IsArray({ message: 'mentions must be an array.' })
  @ValidateNested({ each: true })
  @Type(() => CreatePostMentionDto)
  mentions?: CreatePostMentionDto[];

  @ApiPropertyOptional({
    type: [CreatePostImageDto],
    description: 'Attached images (max 4).',
  })
  @IsOptional()
  @IsArray({ message: 'images must be an array.' })
  @ArrayMaxSize(4, { message: 'A post cannot contain more than 4 images.' })
  @ValidateNested({ each: true })
  @Type(() => CreatePostImageDto)
  images?: CreatePostImageDto[];
}

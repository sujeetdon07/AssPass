import {
  IsString,
  IsNotEmpty,
  MinLength,
  MaxLength,
  IsEnum,
  IsOptional,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PostCategory } from '../../feed/entities/post.entity.js';

export class CreateCommunityPostDto {
  @ApiProperty({
    example: 'Discussion on the upcoming society maintenance schedule.',
    description: 'Post text content',
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(1, { message: 'Post content cannot be empty.' })
  @MaxLength(2000, { message: 'Post content cannot exceed 2000 characters.' })
  content!: string;

  @ApiPropertyOptional({
    enum: PostCategory,
    default: PostCategory.GENERAL,
    description: 'Category for the post',
  })
  @IsOptional()
  @IsEnum(PostCategory, {
    message: 'Invalid category. Must be one of the approved post categories.',
  })
  category?: PostCategory = PostCategory.GENERAL;
}

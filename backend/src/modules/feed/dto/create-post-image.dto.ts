import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  Min,
  MaxLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreatePostImageDto {
  @ApiProperty({
    description: 'Standard / full optimized image URL',
    example: 'http://localhost:3000/api/v1/media/files/img_abc123.webp',
  })
  @IsString()
  @IsNotEmpty({ message: 'Image URL is required.' })
  url!: string;

  @ApiProperty({
    description: 'Thumbnail variant URL',
    example: 'http://localhost:3000/api/v1/media/files/thumb_abc123.webp',
  })
  @IsString()
  @IsNotEmpty({ message: 'Thumbnail URL is required.' })
  thumbnailUrl!: string;

  @ApiPropertyOptional({
    description: 'Medium variant URL for card displays',
    example: 'http://localhost:3000/api/v1/media/files/med_abc123.webp',
  })
  @IsOptional()
  @IsString()
  mediumUrl?: string;

  @ApiPropertyOptional({ description: 'Pixel width of image', example: 1920 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  width?: number;

  @ApiPropertyOptional({ description: 'Pixel height of image', example: 1080 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  height?: number;

  @ApiPropertyOptional({ description: 'MIME type of image', example: 'image/webp' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  mimeType?: string;

  @ApiPropertyOptional({ description: 'File size in bytes', example: 182400 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  size?: number;

  @ApiPropertyOptional({ description: 'Sort order index (0-based)', example: 0, default: 0 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  sortOrder?: number;
}

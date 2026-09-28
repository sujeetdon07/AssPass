import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UploadImageResponseDto {
  @ApiProperty({
    description: 'Public URL to the standard/original optimized image',
    example: 'http://localhost:3000/api/v1/media/files/img_8f8e1234.webp',
  })
  url!: string;

  @ApiProperty({
    description: 'Public URL to the thumbnail variant for list views and cards',
    example: 'http://localhost:3000/api/v1/media/files/thumb_8f8e1234.webp',
  })
  thumbnailUrl!: string;

  @ApiPropertyOptional({
    description: 'Public URL to the medium variant',
    example: 'http://localhost:3000/api/v1/media/files/med_8f8e1234.webp',
  })
  mediumUrl?: string;

  @ApiProperty({
    description: 'Pixel width of the standard image',
    example: 1200,
  })
  width!: number;

  @ApiProperty({
    description: 'Pixel height of the standard image',
    example: 800,
  })
  height!: number;

  @ApiProperty({
    description: 'File size in bytes of the standard image',
    example: 245000,
  })
  size!: number;

  @ApiProperty({
    description: 'MIME type of the processed image',
    example: 'image/webp',
  })
  mimeType!: string;

  @ApiPropertyOptional({
    description: 'Image role or category (e.g. avatar, post, listing, event)',
    example: 'post',
  })
  type?: string;
}

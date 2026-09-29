import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNotEmpty,
  MaxLength,
  IsOptional,
  IsEnum,
  IsInt,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { MessageType } from '../entities/message.entity.js';

export class SendMessageDto {
  @ApiProperty({
    description: 'Unique client-generated idempotency identifier for duplicate message protection',
    example: 'msg_client_1727600000_abc123',
    maxLength: 100,
  })
  @IsString()
  @IsNotEmpty({ message: 'clientMessageId is required' })
  @MaxLength(100, { message: 'clientMessageId must not exceed 100 characters' })
  clientMessageId!: string;

  @ApiPropertyOptional({
    description: 'Text content or caption of the message (plain text)',
    example: 'Hello! Is this item still available?',
    maxLength: 2000,
  })
  @IsOptional()
  @IsString()
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @MaxLength(2000, { message: 'Message content cannot exceed 2000 characters' })
  content?: string;

  @ApiPropertyOptional({
    description: 'Message type: TEXT or IMAGE',
    enum: MessageType,
    default: MessageType.TEXT,
  })
  @IsOptional()
  @IsEnum(MessageType)
  messageType?: MessageType;

  @ApiPropertyOptional({
    description: 'Public URL to the optimized standard image',
    example: 'http://localhost:3000/api/v1/media/files/img_8f8e1234.webp',
  })
  @IsOptional()
  @IsString()
  mediaUrl?: string;

  @ApiPropertyOptional({
    description: 'Public URL to the optimized thumbnail variant',
    example: 'http://localhost:3000/api/v1/media/files/thumb_8f8e1234.webp',
  })
  @IsOptional()
  @IsString()
  mediaThumbnailUrl?: string;

  @ApiPropertyOptional({
    description: 'Pixel width of the image',
    example: 1200,
  })
  @IsOptional()
  @IsInt()
  mediaWidth?: number;

  @ApiPropertyOptional({
    description: 'Pixel height of the image',
    example: 800,
  })
  @IsOptional()
  @IsInt()
  mediaHeight?: number;

  @ApiPropertyOptional({
    description: 'Byte size of the processed image',
    example: 245000,
  })
  @IsOptional()
  @IsInt()
  mediaSize?: number;

  @ApiPropertyOptional({
    description: 'MIME type of the media (e.g. image/webp)',
    example: 'image/webp',
  })
  @IsOptional()
  @IsString()
  mediaMimeType?: string;
}

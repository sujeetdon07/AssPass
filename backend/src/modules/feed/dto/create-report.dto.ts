import {
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ReportReason } from '../entities/report.entity.js';

export class CreateReportDto {
  @ApiProperty({
    enum: ReportReason,
    description: 'Category / reason for reporting content.',
    example: ReportReason.SPAM,
  })
  @IsEnum(ReportReason, { message: 'Invalid report reason.' })
  reason!: ReportReason;

  @ApiPropertyOptional({
    description: 'Optional additional context or explanation (up to 500 characters).',
    example: 'Repeated promotional link posted across multiple threads.',
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MaxLength(500, { message: 'Report details cannot exceed 500 characters.' })
  details?: string;
}

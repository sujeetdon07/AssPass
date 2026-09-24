import { IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { BusinessReportReason } from '../entities/business-report.entity.js';

export class CreateBusinessReportDto {
  @ApiProperty({
    enum: BusinessReportReason,
    description: 'Reason for reporting this business',
    example: BusinessReportReason.INCORRECT_INFO,
  })
  @IsEnum(BusinessReportReason)
  @IsNotEmpty()
  reason!: BusinessReportReason;

  @ApiPropertyOptional({
    description: 'Additional contextual details for moderation',
    maxLength: 500,
    example: 'This store moved to another address 2 months ago.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  details?: string;
}

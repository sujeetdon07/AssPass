import { IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ServiceReportReason } from '../entities/service-report.entity.js';

export class CreateServiceReportDto {
  @ApiProperty({
    enum: ServiceReportReason,
    description: 'Reason for reporting this service listing',
    example: ServiceReportReason.INCORRECT_INFO,
  })
  @IsEnum(ServiceReportReason)
  @IsNotEmpty()
  reason!: ServiceReportReason;

  @ApiPropertyOptional({
    description: 'Additional contextual details for moderation',
    maxLength: 500,
    example: 'Phone number does not work or provider is no longer in service.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  details?: string;
}

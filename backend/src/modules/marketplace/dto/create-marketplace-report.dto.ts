import { IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MarketplaceReportReason } from '../entities/marketplace-report.entity.js';

export class CreateMarketplaceReportDto {
  @ApiProperty({
    enum: MarketplaceReportReason,
    example: MarketplaceReportReason.SCAM,
    description: 'Structured reason for reporting the listing',
  })
  @IsNotEmpty()
  @IsEnum(MarketplaceReportReason, {
    message: 'Invalid report reason. Must be spam, scam, harassment, inappropriate, misinformation, or other.',
  })
  reason!: MarketplaceReportReason;

  @ApiPropertyOptional({
    example: 'Seller requested payment via suspicious external link.',
    description: 'Optional additional context for trust & safety review',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500, { message: 'Details must not exceed 500 characters.' })
  details?: string;
}

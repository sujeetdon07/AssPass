import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { ConversationReportReason } from '../entities/conversation-report.entity.js';

export class ReportConversationDto {
  @ApiProperty({
    description: 'Reason for reporting the conversation or user',
    enum: ConversationReportReason,
    example: ConversationReportReason.HARASSMENT,
  })
  @IsEnum(ConversationReportReason, { message: 'Invalid report reason' })
  @IsNotEmpty({ message: 'Report reason is required' })
  reason!: ConversationReportReason;

  @ApiPropertyOptional({
    description: 'Additional context or details regarding the report',
    example: 'User was sending abusive and inappropriate messages.',
    maxLength: 500,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500, { message: 'Description must not exceed 500 characters' })
  description?: string;

  @ApiPropertyOptional({
    description: 'Specific offending message UUID, if applicable',
    example: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  })
  @IsOptional()
  @IsUUID('4', { message: 'messageId must be a valid UUID' })
  messageId?: string;
}

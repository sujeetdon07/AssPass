import {
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/**
 * Centralized report target types for the Safety module.
 * Covers user profiles, content types across domains, and messaging.
 */
export enum SafetyReportTargetType {
  USER = 'user',
  POST = 'post',
  COMMENT = 'comment',
  LISTING = 'listing',
  BUSINESS = 'business',
  SERVICE = 'service',
  CONVERSATION = 'conversation',
  MESSAGE = 'message',
  EVENT = 'event',
}

/**
 * Controlled report reason categories for the Trust & Safety system.
 * Complies with Phase 10 controlled taxonomy.
 */
export enum SafetyReportReason {
  SPAM = 'spam',
  HARASSMENT = 'harassment',
  HATE_OR_ABUSE = 'hate_or_abuse',
  THREATS = 'threats',
  SCAM_OR_FRAUD = 'scam_or_fraud',
  SEXUAL_CONTENT = 'sexual_content',
  VIOLENCE = 'violence',
  ILLEGAL_ACTIVITY = 'illegal_activity',
  MISINFORMATION = 'misinformation',
  IMPERSONATION = 'impersonation',
  PRIVACY_VIOLATION = 'privacy_violation',
  INAPPROPRIATE_CONTENT = 'inappropriate_content',
  OTHER = 'other',

  // Backward-compatible aliases
  FRAUD = 'fraud',
  INAPPROPRIATE = 'inappropriate',
  MISLEADING = 'misleading',
  ILLEGAL_CONTENT = 'illegal_content',
}

export class CreateSafetyReportDto {
  @ApiProperty({
    enum: SafetyReportTargetType,
    description: 'Type of entity or content being reported.',
    example: SafetyReportTargetType.POST,
  })
  @IsEnum(SafetyReportTargetType, { message: 'Invalid target type.' })
  targetType!: SafetyReportTargetType;

  @ApiProperty({
    description: 'UUID of the target entity/content being reported.',
    example: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  })
  @IsUUID('4', { message: 'targetId must be a valid UUID.' })
  targetId!: string;

  @ApiPropertyOptional({
    description: 'Optional secondary UUID (e.g., messageId within a reported conversation).',
    example: 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
  })
  @IsOptional()
  @IsUUID('4', { message: 'secondaryId must be a valid UUID.' })
  secondaryId?: string;

  @ApiProperty({
    enum: SafetyReportReason,
    description: 'Controlled reason category for reporting.',
    example: SafetyReportReason.SPAM,
  })
  @IsEnum(SafetyReportReason, { message: 'Invalid report reason.' })
  reason!: SafetyReportReason;

  @ApiPropertyOptional({
    description: 'Optional additional context (max 2000 characters).',
    example: 'This user is sending unprompted commercial advertisements in private messages.',
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @MaxLength(2000, { message: 'Details cannot exceed 2000 characters.' })
  details?: string;
}

import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { UserRole, UserStatus } from '../../users/entities/user.entity.js';
import {
  SafetyModerationStatus,
} from '../../safety/entities/safety-report.entity.js';
import { SafetyReportTargetType } from '../../safety/dto/create-safety-report.dto.js';

// ── Pagination ────────────────────────────────────────────────────────────────

export class PaginationQueryDto {
  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 20, minimum: 1, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;
}

// ── Users ─────────────────────────────────────────────────────────────────────

export class AdminUsersQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Search by display name or user ID' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  search?: string;

  @ApiPropertyOptional({ enum: UserRole })
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @ApiPropertyOptional({ enum: UserStatus })
  @IsOptional()
  @IsEnum(UserStatus)
  status?: UserStatus;
}

export class UpdateUserRoleDto {
  @IsEnum(UserRole, { message: 'Invalid role value.' })
  role!: UserRole;
}

export class UpdateUserStatusDto {
  @IsEnum(UserStatus, { message: 'Invalid status value.' })
  status!: UserStatus;

  @IsString()
  @MaxLength(500)
  reason!: string;
}

// ── Reports ───────────────────────────────────────────────────────────────────

export class AdminReportsQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: SafetyModerationStatus })
  @IsOptional()
  @IsEnum(SafetyModerationStatus)
  status?: SafetyModerationStatus;

  @ApiPropertyOptional({ enum: SafetyReportTargetType })
  @IsOptional()
  @IsEnum(SafetyReportTargetType)
  targetType?: SafetyReportTargetType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(50)
  reason?: string;
}

// ── Audit Logs ────────────────────────────────────────────────────────────────

export class AdminAuditLogsQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Filter by actor user ID' })
  @IsOptional()
  @IsUUID('4')
  actorId?: string;

  @ApiPropertyOptional({ description: 'Filter by action string' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  action?: string;

  @ApiPropertyOptional({ description: 'Filter by target type' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  targetType?: string;
}

// ── Content ───────────────────────────────────────────────────────────────────

export class AdminContentQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Search term' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  search?: string;
}

// ── Staff ─────────────────────────────────────────────────────────────────────

export class AdminStaffQueryDto extends PaginationQueryDto {}

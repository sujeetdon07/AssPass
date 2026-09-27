import {
  Controller,
  Get,
  Post,
  Delete,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
  ApiParam,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard } from '../auth/guards/roles.guard.js';
import { Roles } from '../auth/decorators/roles.decorator.js';
import { UserRole } from '../users/entities/user.entity.js';
import {
  CurrentUser,
  type CurrentUserPayload,
} from '../auth/decorators/current-user.decorator.js';
import { SafetyService } from './safety.service.js';
import { CreateSafetyReportDto } from './dto/create-safety-report.dto.js';
import { SafetyModerationStatus } from './entities/safety-report.entity.js';

/**
 * Trust & Safety controller.
 *
 * Provides a single, authenticated surface for:
 * - Blocking / unblocking users
 * - Listing caller's blocked users
 * - Submitting content / user / conversation reports across all domains
 * - Viewing report history (own reports only)
 * - Moderation status lifecycle & audit trail (moderator/admin restricted)
 *
 * All endpoints are authenticated. Caller identity is always taken from
 * the JWT — never from request body fields — to prevent spoofing.
 */
@ApiTags('safety')
@Controller({ path: 'safety', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('access-token')
export class SafetyController {
  constructor(private readonly safetyService: SafetyService) {}

  // ── Block Endpoints ──────────────────────────────────────────────────────────

  @Post('blocks')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Block a user from interacting with you',
    description: 'Prevents target user from direct messaging or private interactions with the caller.',
  })
  @ApiResponse({ status: 200, description: 'User blocked successfully' })
  @ApiResponse({ status: 400, description: 'Cannot block yourself' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 404, description: 'Target user not found' })
  async blockUser(
    @CurrentUser() user: CurrentUserPayload,
    @Body('userId', ParseUUIDPipe) blockedId: string,
  ) {
    return this.safetyService.blockUser(user.userId, blockedId);
  }

  @Delete('blocks/:userId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Unblock a previously blocked user',
    description: 'Removes the block relationship between the caller and the target user.',
  })
  @ApiParam({ name: 'userId', description: 'UUID of the user to unblock' })
  @ApiResponse({ status: 200, description: 'User unblocked successfully' })
  @ApiResponse({ status: 400, description: 'Invalid request' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async unblockUser(
    @Param('userId', ParseUUIDPipe) blockedId: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.safetyService.unblockUser(user.userId, blockedId);
  }

  @Get('blocks')
  @ApiOperation({
    summary: 'Get paginated list of users blocked by the current user',
    description: 'Returns safe public projections only — no phone numbers, email, or private data.',
  })
  @ApiResponse({ status: 200, description: 'Paginated blocked users list' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'cursor', required: false, type: String })
  async getBlockedUsers(
    @CurrentUser() user: CurrentUserPayload,
    @Query('limit') limit?: number,
    @Query('cursor') cursor?: string,
  ) {
    const parsedLimit = limit ? Math.min(Number(limit), 50) : 20;
    return this.safetyService.getBlockedUsers(user.userId, parsedLimit, cursor);
  }

  // ── Report Endpoints ─────────────────────────────────────────────────────────

  @Post('reports')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Submit a content, profile, or messaging safety report',
    description:
      'Unified safety report endpoint. Validates target existence and authorization, ' +
      'prevents active duplicate reports, and rate-limits to 10 reports per hour.',
  })
  @ApiResponse({ status: 200, description: 'Report submitted successfully' })
  @ApiResponse({ status: 400, description: 'Invalid input or self-reporting' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 403, description: 'Forbidden (unauthorized to report private resource)' })
  @ApiResponse({ status: 404, description: 'Report target not found' })
  @ApiResponse({ status: 409, description: 'Active report already exists for this target' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (10 reports/hour)' })
  async submitReport(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateSafetyReportDto,
  ) {
    return this.safetyService.submitReport(user.userId, dto);
  }

  @Get('reports/me')
  @ApiOperation({
    summary: 'Get report history for the current user',
    description:
      'Returns reports submitted by the caller. Strictly excludes reviewer identities, ' +
      'internal notes, and other users private data.',
  })
  @ApiResponse({ status: 200, description: 'User report history list' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'cursor', required: false, type: String })
  async getMyReports(
    @CurrentUser() user: CurrentUserPayload,
    @Query('limit') limit?: number,
    @Query('cursor') cursor?: string,
  ) {
    const parsedLimit = limit ? Math.min(Number(limit), 50) : 20;
    return this.safetyService.getMyReports(user.userId, parsedLimit, cursor);
  }

  // ── Internal Moderation Endpoints (Phase 11 Foundation) ──────────────────────

  @Patch('reports/:reportId/status')
  @UseGuards(RolesGuard)
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({
    summary: 'Update moderation report status',
    description: 'Restricted to MODERATOR and ADMIN roles.',
  })
  @ApiParam({ name: 'reportId', description: 'UUID of the safety report' })
  @ApiResponse({ status: 200, description: 'Status updated' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 403, description: 'Forbidden (insufficient permissions)' })
  @ApiResponse({ status: 404, description: 'Report not found' })
  async updateReportStatus(
    @Param('reportId', ParseUUIDPipe) reportId: string,
    @Body('status') status: SafetyModerationStatus,
    @Body('reason') reason: string | undefined,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.safetyService.updateReportStatus(reportId, status, user.userId, reason);
  }

  @Get('audit-logs')
  @UseGuards(RolesGuard)
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({
    summary: 'View moderation audit logs',
    description: 'Restricted to MODERATOR and ADMIN roles.',
  })
  @ApiResponse({ status: 200, description: 'Audit logs' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 403, description: 'Forbidden (insufficient permissions)' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'cursor', required: false, type: String })
  async getAuditLogs(
    @Query('limit') limit?: number,
    @Query('cursor') cursor?: string,
  ) {
    const parsedLimit = limit ? Math.min(Number(limit), 50) : 20;
    return this.safetyService.getAuditLogs(parsedLimit, cursor);
  }
}

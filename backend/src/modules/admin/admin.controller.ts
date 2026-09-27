import {
  Controller,
  Get,
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
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard } from '../auth/guards/roles.guard.js';
import { Roles } from '../auth/decorators/roles.decorator.js';
import { UserRole } from '../users/entities/user.entity.js';
import {
  CurrentUser,
  type CurrentUserPayload,
} from '../auth/decorators/current-user.decorator.js';
import { AdminService } from './admin.service.js';
import {
  AdminUsersQueryDto,
  AdminReportsQueryDto,
  AdminAuditLogsQueryDto,
  AdminContentQueryDto,
  AdminStaffQueryDto,
  UpdateUserRoleDto,
  UpdateUserStatusDto,
} from './dto/admin.dto.js';

/**
 * Admin Dashboard Controller — Phase 11
 *
 * All routes are under /api/v1/admin.
 * - JwtAuthGuard: enforces authentication on all routes (class-level)
 * - RolesGuard + @Roles: enforces MODERATOR/ADMIN as required per route
 *
 * Privacy: Safe projections are always used. No credentials, exact GPS,
 * phone numbers, FCM tokens, or refresh token hashes are returned.
 *
 * Audit: Every privileged mutation creates an entry in moderation_audit_logs.
 */
@ApiTags('admin')
@Controller({ path: 'admin', version: '1' })
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth('access-token')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // ── Dashboard ─────────────────────────────────────────────────────────────

  @Get('dashboard/summary')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({
    summary: 'Get admin dashboard summary metrics',
    description: 'Returns aggregated user, moderation, and content counts.',
  })
  @ApiResponse({ status: 200, description: 'Dashboard summary data' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 403, description: 'Forbidden — MODERATOR or ADMIN required' })
  async getDashboardSummary() {
    return this.adminService.getDashboardSummary();
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  @Get('users')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({
    summary: 'List users with filters and pagination',
    description:
      'Server-side paginated user list. Safe projection — no phone, coords, or tokens exposed.',
  })
  @ApiResponse({ status: 200, description: 'Paginated user list' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  async listUsers(@Query() query: AdminUsersQueryDto) {
    return this.adminService.listUsers(
      query.page ?? 1,
      query.limit ?? 20,
      query.search,
      query.role,
      query.status,
    );
  }

  @Get('users/:id')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({ summary: 'Get user details by ID (safe projection)' })
  @ApiParam({ name: 'id', description: 'User UUID' })
  @ApiResponse({ status: 200, description: 'User details' })
  @ApiResponse({ status: 404, description: 'User not found' })
  async getUserById(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.getUserById(id);
  }

  @Get('users/:id/reports')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({ summary: 'Get report history filed by a specific user' })
  @ApiParam({ name: 'id', description: 'User UUID' })
  async getUserReports(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: AdminContentQueryDto,
  ) {
    return this.adminService.getUserReportHistory(
      id,
      query.page ?? 1,
      query.limit ?? 20,
    );
  }

  @Patch('users/:id/role')
  @HttpCode(HttpStatus.OK)
  @Roles(UserRole.ADMIN)
  @ApiOperation({
    summary: 'Change a user role (ADMIN only)',
    description:
      'Promotes or demotes a user role. Moderators cannot change roles. ' +
      'ADMIN role requires ADMIN actor. Creates audit log.',
  })
  @ApiParam({ name: 'id', description: 'Target user UUID' })
  @ApiResponse({ status: 200, description: 'Role updated' })
  @ApiResponse({ status: 400, description: 'Self-role-change rejected' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'User not found' })
  async updateUserRole(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserRoleDto,
    @CurrentUser() actor: CurrentUserPayload,
  ) {
    return this.adminService.updateUserRole(
      actor.userId,
      id,
      dto.role,
      actor.role as UserRole,
    );
  }

  @Patch('users/:id/status')
  @HttpCode(HttpStatus.OK)
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({
    summary: 'Suspend or restore a user account',
    description:
      'Updates account status (active/suspended). Creates audit log.',
  })
  @ApiParam({ name: 'id', description: 'Target user UUID' })
  @ApiResponse({ status: 200, description: 'Status updated' })
  @ApiResponse({ status: 400, description: 'Invalid status or self-action' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'User not found' })
  async updateUserStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserStatusDto,
    @CurrentUser() actor: CurrentUserPayload,
  ) {
    return this.adminService.updateUserStatus(
      actor.userId,
      id,
      dto.status,
      dto.reason,
    );
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  @Get('reports')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({
    summary: 'List safety reports with filters and pagination',
  })
  @ApiResponse({ status: 200, description: 'Paginated reports list' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  async listReports(@Query() query: AdminReportsQueryDto) {
    return this.adminService.listReports(
      query.page ?? 1,
      query.limit ?? 20,
      query.status,
      query.targetType,
      query.reason,
    );
  }

  @Get('reports/:id')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({ summary: 'Get safety report details by ID' })
  @ApiParam({ name: 'id', description: 'Report UUID' })
  @ApiResponse({ status: 200, description: 'Report details' })
  @ApiResponse({ status: 404, description: 'Report not found' })
  async getReportById(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.getReportById(id);
  }

  // ── Staff ─────────────────────────────────────────────────────────────────

  @Get('staff')
  @Roles(UserRole.ADMIN)
  @ApiOperation({
    summary: 'List staff users (MODERATOR + ADMIN) — ADMIN only',
  })
  @ApiResponse({ status: 200, description: 'Paginated staff list' })
  @ApiResponse({ status: 403, description: 'Forbidden — ADMIN required' })
  async listStaff(@Query() query: AdminStaffQueryDto) {
    return this.adminService.listStaff(query.page ?? 1, query.limit ?? 20);
  }

  // ── Audit Logs ────────────────────────────────────────────────────────────

  @Get('audit-logs')
  @Roles(UserRole.ADMIN)
  @ApiOperation({
    summary: 'List moderation audit logs — ADMIN only',
    description: 'Read-only audit trail. Cannot be edited or deleted.',
  })
  @ApiQuery({ name: 'actorId', required: false })
  @ApiQuery({ name: 'action', required: false })
  @ApiQuery({ name: 'targetType', required: false })
  @ApiResponse({ status: 200, description: 'Paginated audit logs' })
  @ApiResponse({ status: 403, description: 'Forbidden — ADMIN required' })
  async listAuditLogs(@Query() query: AdminAuditLogsQueryDto) {
    return this.adminService.listAuditLogs(
      query.page ?? 1,
      query.limit ?? 20,
      query.actorId,
      query.action,
      query.targetType,
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  @Get('marketplace')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({ summary: 'List marketplace listings (admin view, includes deleted)' })
  @ApiResponse({ status: 200, description: 'Paginated listings' })
  async listListings(@Query() query: AdminContentQueryDto) {
    return this.adminService.listListings(
      query.page ?? 1,
      query.limit ?? 20,
      query.search,
    );
  }

  @Get('businesses')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({ summary: 'List businesses (admin view)' })
  @ApiResponse({ status: 200, description: 'Paginated businesses' })
  async listBusinesses(@Query() query: AdminContentQueryDto) {
    return this.adminService.listBusinesses(
      query.page ?? 1,
      query.limit ?? 20,
      query.search,
    );
  }

  @Get('services')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({ summary: 'List services (admin view)' })
  @ApiResponse({ status: 200, description: 'Paginated services' })
  async listServices(@Query() query: AdminContentQueryDto) {
    return this.adminService.listServices(
      query.page ?? 1,
      query.limit ?? 20,
      query.search,
    );
  }

  @Get('communities')
  @Roles(UserRole.MODERATOR, UserRole.ADMIN)
  @ApiOperation({ summary: 'List communities (admin view)' })
  @ApiResponse({ status: 200, description: 'Paginated communities' })
  async listCommunities(@Query() query: AdminContentQueryDto) {
    return this.adminService.listCommunities(
      query.page ?? 1,
      query.limit ?? 20,
      query.search,
    );
  }
}

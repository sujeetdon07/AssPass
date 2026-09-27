import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import {
  CurrentUser,
  type CurrentUserPayload,
} from '../auth/decorators/current-user.decorator.js';
import { NotificationsService } from './notifications.service.js';
import { GetNotificationsQueryDto } from './dto/get-notifications-query.dto.js';
import { RegisterDeviceDto } from './dto/register-device.dto.js';
import { UpdateNotificationPreferencesDto } from './dto/update-preferences.dto.js';
import { serializeNotificationPreferences } from './serializers/notification-preferences.serializer.js';

@ApiTags('notifications')
@Controller({ path: 'notifications', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('access-token')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'Get paginated notifications for current user' })
  @ApiResponse({ status: 200, description: 'Paginated list of notifications' })
  async getNotifications(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetNotificationsQueryDto,
  ) {
    return this.notificationsService.getNotifications(user.userId, query);
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Get unread notification count for current user' })
  @ApiResponse({ status: 200, description: 'Unread notification count' })
  async getUnreadCount(@CurrentUser() user: CurrentUserPayload) {
    const count = await this.notificationsService.getUnreadCount(user.userId);
    return { count };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark single notification as read' })
  @ApiResponse({ status: 200, description: 'Notification marked as read' })
  @ApiResponse({ status: 404, description: 'Notification not found' })
  async markAsRead(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.notificationsService.markAsRead(user.userId, id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a single notification' })
  @ApiResponse({ status: 200, description: 'Notification deleted successfully' })
  @ApiResponse({ status: 404, description: 'Notification not found' })
  async deleteNotification(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.notificationsService.deleteNotification(user.userId, id);
    return { success: true };
  }

  @Post('read-all')
  @ApiOperation({ summary: 'Mark all notifications as read for current user' })
  @ApiResponse({ status: 200, description: 'All notifications marked as read' })
  async markAllAsRead(@CurrentUser() user: CurrentUserPayload) {
    return this.notificationsService.markAllAsRead(user.userId);
  }

  @Post('devices')
  @ApiOperation({ summary: 'Register or refresh device push notification token' })
  @ApiResponse({ status: 201, description: 'Device token registered successfully' })
  async registerDevice(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: RegisterDeviceDto,
  ) {
    const token = await this.notificationsService.registerDevice(user.userId, dto);
    return {
      id: token.id,
      platform: token.platform,
      isActive: token.isActive,
      lastUsedAt: token.lastUsedAt,
    };
  }

  @Delete('devices/:token')
  @ApiOperation({ summary: 'Unregister device push token (e.g. on logout)' })
  @ApiResponse({ status: 200, description: 'Device token unregistered successfully' })
  async unregisterDevice(
    @CurrentUser() user: CurrentUserPayload,
    @Param('token') token: string,
  ) {
    await this.notificationsService.unregisterDevice(user.userId, token);
    return { success: true };
  }

  @Get('preferences')
  @ApiOperation({ summary: 'Get current notification channel & category preferences' })
  @ApiResponse({ status: 200, description: 'User notification preferences' })
  async getPreferences(@CurrentUser() user: CurrentUserPayload) {
    const prefs = await this.notificationsService.getPreferences(user.userId);
    return serializeNotificationPreferences(prefs);
  }

  @Patch('preferences')
  @ApiOperation({ summary: 'Update notification channel & category preferences' })
  @ApiResponse({ status: 200, description: 'Updated notification preferences' })
  async updatePreferences(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateNotificationPreferencesDto,
  ) {
    const prefs = await this.notificationsService.updatePreferences(user.userId, dto);
    return serializeNotificationPreferences(prefs);
  }
}

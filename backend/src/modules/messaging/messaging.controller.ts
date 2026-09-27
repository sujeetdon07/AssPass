import {
  Controller,
  Get,
  Post,
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
import { MessagingService } from './messaging.service.js';
import { CreateConversationDto } from './dto/create-conversation.dto.js';
import { SendMessageDto } from './dto/send-message.dto.js';
import { GetConversationsQueryDto } from './dto/get-conversations-query.dto.js';
import { GetMessagesQueryDto } from './dto/get-messages-query.dto.js';
import { ReportConversationDto } from './dto/report-conversation.dto.js';
import { BlockUserDto } from './dto/block-user.dto.js';

@ApiTags('messaging')
@Controller({ path: 'messaging', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('access-token')
export class MessagingController {
  constructor(private readonly messagingService: MessagingService) {}

  @Post('conversations')
  @ApiOperation({ summary: 'Start or retrieve a direct one-to-one conversation with a neighbor' })
  @ApiResponse({ status: 201, description: 'Conversation retrieved or created successfully' })
  @ApiResponse({ status: 400, description: 'Cannot message yourself or invalid target' })
  @ApiResponse({ status: 403, description: 'Conversation unavailable due to block' })
  async createOrGetConversation(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateConversationDto,
  ) {
    return this.messagingService.getOrCreateConversation(user.userId, dto.participantId);
  }

  @Get('conversations')
  @ApiOperation({ summary: "Get current user's active conversations with cursor pagination" })
  @ApiResponse({ status: 200, description: 'Paginated conversation list' })
  async getConversations(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetConversationsQueryDto,
  ) {
    return this.messagingService.getConversations(user.userId, query);
  }

  @Get('conversations/:id')
  @ApiOperation({ summary: 'Get details of a specific conversation' })
  @ApiResponse({ status: 200, description: 'Conversation details' })
  @ApiResponse({ status: 403, description: 'Forbidden - not a participant' })
  @ApiResponse({ status: 404, description: 'Conversation not found' })
  async getConversationById(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.messagingService.getConversationById(id, user.userId);
  }

  @Get('conversations/:id/messages')
  @ApiOperation({ summary: 'Get paginated message history for a conversation' })
  @ApiResponse({ status: 200, description: 'Paginated message history' })
  @ApiResponse({ status: 403, description: 'Forbidden - not a participant' })
  async getMessages(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetMessagesQueryDto,
  ) {
    return this.messagingService.getMessages(id, user.userId, query);
  }

  @Post('conversations/:id/messages')
  @ApiOperation({ summary: 'Send a message into a conversation (REST fallback)' })
  @ApiResponse({ status: 201, description: 'Message sent successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not a participant or blocked' })
  @ApiResponse({ status: 429, description: 'Too many messages sent' })
  async sendMessage(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: SendMessageDto,
  ) {
    const { message } = await this.messagingService.sendMessage(id, user.userId, dto);
    return message;
  }

  @Post('conversations/:id/read')
  @ApiOperation({ summary: 'Mark all unread messages in a conversation as read' })
  @ApiResponse({ status: 200, description: 'Messages marked as read' })
  async markAsRead(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.messagingService.markAsRead(id, user.userId);
  }

  @Delete('messages/:id')
  @ApiOperation({ summary: 'Soft delete a message sent by current user' })
  @ApiResponse({ status: 200, description: 'Message deleted' })
  @ApiResponse({ status: 403, description: 'Forbidden - cannot delete other user messages' })
  async deleteMessage(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.messagingService.deleteMessage(id, user.userId);
  }

  @Post('conversations/:id/report')
  @ApiOperation({ summary: 'Report a conversation for moderation review' })
  @ApiResponse({ status: 201, description: 'Report submitted successfully' })
  @ApiResponse({ status: 409, description: 'Report already submitted' })
  async reportConversation(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: ReportConversationDto,
  ) {
    return this.messagingService.reportConversation(user.userId, id, dto);
  }

  @Post('blocks')
  @ApiOperation({ summary: 'Block a user from contacting you' })
  @ApiResponse({ status: 200, description: 'User blocked' })
  async blockUser(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: BlockUserDto,
  ) {
    return this.messagingService.blockUser(user.userId, dto.userId);
  }

  @Delete('blocks/:userId')
  @ApiOperation({ summary: 'Unblock a previously blocked user' })
  @ApiResponse({ status: 200, description: 'User unblocked' })
  async unblockUser(
    @Param('userId', ParseUUIDPipe) targetUserId: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.messagingService.unblockUser(user.userId, targetUserId);
  }

  @Get('presence/:userId')
  @ApiOperation({ summary: 'Check online status for a user' })
  @ApiResponse({ status: 200, description: 'Presence status' })
  async getPresence(@Param('userId', ParseUUIDPipe) targetUserId: string) {
    const isOnline = await this.messagingService.isUserOnline(targetUserId);
    return {
      userId: targetUserId,
      status: isOnline ? 'online' : 'offline',
    };
  }
}

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
  HttpCode,
  HttpStatus,
  ParseUUIDPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser, type CurrentUserPayload } from '../auth/decorators/current-user.decorator.js';
import { FeedService } from './services/feed.service.js';
import { ReactionsService } from './services/reactions.service.js';
import { CommentsService } from './services/comments.service.js';
import { ReportsService } from './services/reports.service.js';
import { CreatePostDto } from './dto/create-post.dto.js';
import { UpdatePostDto } from './dto/update-post.dto.js';
import { GetFeedQueryDto } from './dto/get-feed-query.dto.js';
import { CreateCommentDto } from './dto/create-comment.dto.js';
import { CreateReportDto } from './dto/create-report.dto.js';

@ApiTags('feed')
@Controller({ path: 'feed', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('access-token')
export class FeedController {
  constructor(
    private readonly feedService: FeedService,
    private readonly reactionsService: ReactionsService,
    private readonly commentsService: CommentsService,
    private readonly reportsService: ReportsService,
  ) {}

  @Get('posts')
  @ApiOperation({ summary: 'List community feed posts with cursor pagination and locality scoping' })
  @ApiResponse({ status: 200, description: 'Paginated community feed posts' })
  async getFeed(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetFeedQueryDto,
  ) {
    return this.feedService.getFeed(user.userId, query);
  }

  @Post('posts')
  @ApiOperation({ summary: 'Create a new community post' })
  @ApiResponse({ status: 201, description: 'Post successfully created' })
  async createPost(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreatePostDto,
  ) {
    return this.feedService.createPost(user.userId, dto);
  }

  @Get('posts/:id')
  @ApiOperation({ summary: 'Get details for a single post' })
  @ApiResponse({ status: 200, description: 'Post details' })
  @ApiResponse({ status: 404, description: 'Post not found' })
  async getPostById(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.feedService.getPostById(id, user.userId);
  }

  @Patch('posts/:id')
  @ApiOperation({ summary: 'Edit own post content' })
  @ApiResponse({ status: 200, description: 'Post updated' })
  @ApiResponse({ status: 403, description: 'Forbidden - not author' })
  async updatePost(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdatePostDto,
  ) {
    return this.feedService.updatePost(id, user.userId, dto);
  }

  @Delete('posts/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete own post' })
  @ApiResponse({ status: 204, description: 'Post deleted' })
  @ApiResponse({ status: 403, description: 'Forbidden - not author' })
  async deletePost(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    await this.feedService.deletePost(id, user.userId);
  }

  @Post('posts/:id/like')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Like a post (idempotent)' })
  @ApiResponse({ status: 200, description: 'Liked state' })
  async likePost(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.reactionsService.likePost(id, user.userId);
  }

  @Delete('posts/:id/like')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unlike a post (idempotent)' })
  @ApiResponse({ status: 200, description: 'Unliked state' })
  async unlikePost(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.reactionsService.unlikePost(id, user.userId);
  }

  @Get('posts/:id/comments')
  @ApiOperation({ summary: 'List comments for a post' })
  @ApiResponse({ status: 200, description: 'Paginated comments list' })
  async getComments(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Query('cursor') cursor?: string,
    @Query('limit') limit: number = 20,
  ) {
    return this.commentsService.getComments(id, user.userId, limit, cursor);
  }

  @Post('posts/:id/comments')
  @ApiOperation({ summary: 'Add a comment to a post' })
  @ApiResponse({ status: 201, description: 'Comment created' })
  async createComment(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateCommentDto,
  ) {
    return this.commentsService.createComment(id, user.userId, dto);
  }

  @Delete('comments/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete own comment' })
  @ApiResponse({ status: 204, description: 'Comment deleted' })
  @ApiResponse({ status: 403, description: 'Forbidden - not comment author' })
  async deleteComment(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    await this.commentsService.deleteComment(id, user.userId);
  }

  @Post('posts/:id/report')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Report a post for review' })
  @ApiResponse({ status: 200, description: 'Report accepted' })
  @ApiResponse({ status: 409, description: 'Already reported' })
  async reportPost(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateReportDto,
  ) {
    return this.reportsService.reportPost(id, user.userId, dto);
  }

  @Post('comments/:id/report')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Report a comment for review' })
  @ApiResponse({ status: 200, description: 'Report accepted' })
  @ApiResponse({ status: 409, description: 'Already reported' })
  async reportComment(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateReportDto,
  ) {
    return this.reportsService.reportComment(id, user.userId, dto);
  }
}

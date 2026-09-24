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
import { CommunitiesService } from './services/communities.service.js';
import { CreateCommunityDto } from './dto/create-community.dto.js';
import { UpdateCommunityDto } from './dto/update-community.dto.js';
import { GetCommunitiesQueryDto } from './dto/get-communities-query.dto.js';
import { CreateCommunityPostDto } from './dto/create-community-post.dto.js';
import { CreateReportDto } from '../feed/dto/create-report.dto.js';

@ApiTags('communities')
@Controller({ path: 'communities', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('access-token')
export class CommunitiesController {
  constructor(private readonly communitiesService: CommunitiesService) {}

  @Get()
  @ApiOperation({ summary: 'Discover and list communities with search, category, and locality filters' })
  @ApiResponse({ status: 200, description: 'Paginated list of communities' })
  async getCommunities(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetCommunitiesQueryDto,
  ) {
    return this.communitiesService.getCommunities(user.userId, query);
  }

  @Post()
  @ApiOperation({ summary: 'Create a new local community' })
  @ApiResponse({ status: 201, description: 'Community created successfully' })
  async createCommunity(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateCommunityDto,
  ) {
    return this.communitiesService.createCommunity(user.userId, dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get community details and current user membership state' })
  @ApiResponse({ status: 200, description: 'Community details' })
  @ApiResponse({ status: 404, description: 'Community not found' })
  async getCommunityById(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.communitiesService.getCommunityById(id, user.userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update community details (Owner / Moderator only)' })
  @ApiResponse({ status: 200, description: 'Community updated successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async updateCommunity(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateCommunityDto,
  ) {
    return this.communitiesService.updateCommunity(id, user.userId, dto);
  }

  @Post(':id/join')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Join a community' })
  @ApiResponse({ status: 200, description: 'Joined community' })
  async joinCommunity(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.communitiesService.joinCommunity(id, user.userId);
  }

  @Delete(':id/membership')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Leave a community' })
  @ApiResponse({ status: 200, description: 'Left community' })
  @ApiResponse({ status: 400, description: 'Owner cannot leave without ownership transfer' })
  async leaveCommunity(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.communitiesService.leaveCommunity(id, user.userId);
  }

  @Post(':id/leave')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Leave a community (alias)' })
  @ApiResponse({ status: 200, description: 'Left community' })
  @ApiResponse({ status: 400, description: 'Owner cannot leave without ownership transfer' })
  async leaveCommunityAlias(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.communitiesService.leaveCommunity(id, user.userId);
  }

  @Get(':id/membership')
  @ApiOperation({ summary: 'Get current user membership state for a community' })
  @ApiResponse({ status: 200, description: 'Membership state' })
  async getMembership(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.communitiesService.getMembership(id, user.userId);
  }

  @Get(':id/members')
  @ApiOperation({ summary: 'List paginated members of a community' })
  @ApiResponse({ status: 200, description: 'Paginated members' })
  @ApiResponse({ status: 403, description: 'Forbidden for private communities if not a member' })
  async getMembers(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Query('cursor') cursor?: string,
    @Query('limit') limit: number = 20,
  ) {
    return this.communitiesService.getMembers(id, user.userId, limit, cursor);
  }

  @Get(':id/posts')
  @ApiOperation({ summary: 'List paginated posts in a community' })
  @ApiResponse({ status: 200, description: 'Paginated posts in community' })
  @ApiResponse({ status: 403, description: 'Forbidden for private communities if not a member' })
  async getCommunityPosts(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Query('cursor') cursor?: string,
    @Query('limit') limit: number = 20,
  ) {
    return this.communitiesService.getCommunityPosts(id, user.userId, limit, cursor);
  }

  @Post(':id/posts')
  @ApiOperation({ summary: 'Create a post inside a community' })
  @ApiResponse({ status: 201, description: 'Post created' })
  @ApiResponse({ status: 403, description: 'Forbidden if not a member' })
  async createCommunityPost(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateCommunityPostDto,
  ) {
    return this.communitiesService.createCommunityPost(id, user.userId, dto);
  }

  @Post(':id/report')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Report a community for review' })
  @ApiResponse({ status: 200, description: 'Report accepted' })
  @ApiResponse({ status: 409, description: 'Already reported' })
  async reportCommunity(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateReportDto,
  ) {
    return this.communitiesService.reportCommunity(id, user.userId, dto);
  }
}

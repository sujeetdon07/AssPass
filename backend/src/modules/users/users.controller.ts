import {
  Controller,
  Get,
  Patch,
  Body,
  Query,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { UsersService } from './users.service.js';
import { CompleteOnboardingDto } from './dto/complete-onboarding.dto.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
import { UpdateUsernameDto } from './dto/update-username.dto.js';
import { UserSearchQueryDto } from './dto/user-search-query.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard.js';
import {
  CurrentUser,
  type CurrentUserPayload,
} from '../auth/decorators/current-user.decorator.js';

@ApiTags('users')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Get current authenticated user profile' })
  @ApiResponse({ status: 200, description: 'User profile retrieved successfully' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async getProfile(@CurrentUser() user: CurrentUserPayload) {
    return this.usersService.getProfile(user.userId);
  }

  @Get('check-username')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: 'Check username availability in real-time' })
  @ApiQuery({ name: 'username', example: 'sujeet_kumar' })
  @ApiResponse({
    status: 200,
    description: 'Username availability check result',
    schema: {
      type: 'object',
      properties: {
        username: { type: 'string', example: 'sujeet' },
        available: { type: 'boolean', example: true },
        message: { type: 'string', example: 'This username is available' },
      },
    },
  })
  async checkUsername(
    @Query('username') username: string,
    @CurrentUser() user?: CurrentUserPayload | null,
  ) {
    return this.usersService.checkUsernameAvailability(
      username ?? '',
      user?.userId,
    );
  }

  @Patch('me/username')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Update authenticated user unique public @username' })
  @ApiResponse({ status: 200, description: 'Username updated successfully' })
  @ApiResponse({ status: 400, description: 'Invalid username format or reserved name' })
  @ApiResponse({ status: 409, description: 'Username already taken' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async updateUsername(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateUsernameDto,
  ) {
    return this.usersService.updateUsername(user.userId, dto.username);
  }

  @Get('search')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Search users by username (@sujeet or sujeet) or display name' })
  @ApiResponse({ status: 200, description: 'List of matching public user profiles' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async searchUsers(@Query() query: UserSearchQueryDto) {
    return this.usersService.searchUsers(query.q, query.limit, query.page);
  }

  @Get('username/:username')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Get public profile for a user by their unique @username' })
  @ApiResponse({ status: 200, description: 'Public profile retrieved successfully' })
  @ApiResponse({ status: 404, description: 'User not found' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async getUserByUsername(@Param('username') username: string) {
    return this.usersService.getUserByUsername(username);
  }

  @Patch('me/profile')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Update authenticated user profile (name, bio, avatar, locality, username)' })
  @ApiResponse({ status: 200, description: 'Profile updated successfully' })
  @ApiResponse({ status: 400, description: 'Validation failed' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async updateProfile(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.usersService.updateProfile(user.userId, dto);
  }

  @Patch('me/onboarding')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Complete initial user onboarding with display name and locality' })
  @ApiResponse({ status: 200, description: 'Onboarding completed successfully' })
  @ApiResponse({ status: 400, description: 'Validation failed' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async completeOnboarding(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CompleteOnboardingDto,
  ) {
    return this.usersService.completeOnboarding(user.userId, dto);
  }
}

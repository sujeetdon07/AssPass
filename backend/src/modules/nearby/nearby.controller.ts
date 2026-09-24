import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser, type CurrentUserPayload } from '../auth/decorators/current-user.decorator.js';
import { NearbyService } from './services/nearby.service.js';
import { GetNearbyPostsDto } from './dto/get-nearby-posts.dto.js';
import { PaginatedNearbyResponse } from './dto/nearby-post-response.dto.js';

@ApiTags('Nearby')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('nearby')
export class NearbyController {
  constructor(private readonly nearbyService: NearbyService) {}

  @Get('posts')
  @ApiOperation({
    summary: 'Discover nearby posts by radius and device/fallback coordinates',
    description:
      'Performs PostGIS spatial radius discovery around the provided latitude/longitude. Returns privacy-safe distances and deterministic cursor pagination.',
  })
  @ApiResponse({
    status: 200,
    description: 'Paginated list of nearby community posts',
    type: PaginatedNearbyResponse,
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid coordinates, invalid radius, or malformed parameters',
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized. Valid access token required.',
  })
  @ApiResponse({
    status: 429,
    description: 'Too many nearby searches. Rate limit exceeded.',
  })
  async getNearbyPosts(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetNearbyPostsDto,
  ): Promise<PaginatedNearbyResponse> {
    return this.nearbyService.getNearbyPosts(user.userId, query);
  }
}

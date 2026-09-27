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
import {
  CurrentUser,
  type CurrentUserPayload,
} from '../auth/decorators/current-user.decorator.js';
import { MarketplaceService } from './services/marketplace.service.js';
import { CreateListingDto } from './dto/create-listing.dto.js';
import { UpdateListingDto } from './dto/update-listing.dto.js';
import { UpdateListingStatusDto } from './dto/update-listing-status.dto.js';
import { GetListingsQueryDto } from './dto/get-listings-query.dto.js';
import { CreateMarketplaceReportDto } from './dto/create-marketplace-report.dto.js';
import { MarketplaceListingStatus } from './entities/marketplace-listing.entity.js';

@ApiTags('marketplace')
@Controller({ path: 'marketplace', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('access-token')
export class MarketplaceController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get('listings')
  @ApiOperation({
    summary: 'Discover marketplace listings with search, filters, PostGIS radius, and pagination',
  })
  @ApiResponse({ status: 200, description: 'Paginated marketplace listings' })
  async getListings(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetListingsQueryDto,
  ) {
    return this.marketplaceService.getListings(user.userId, query);
  }

  @Post('listings')
  @ApiOperation({ summary: 'Create a new marketplace listing' })
  @ApiResponse({ status: 201, description: 'Listing created successfully' })
  async createListing(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateListingDto,
  ) {
    return this.marketplaceService.createListing(user.userId, dto);
  }

  @Get('listings/me')
  @ApiOperation({ summary: "Get current user's listings (active, sold, or archived)" })
  @ApiResponse({ status: 200, description: 'User listings' })
  async getMyListings(
    @CurrentUser() user: CurrentUserPayload,
    @Query('status') status?: MarketplaceListingStatus,
    @Query('cursor') cursor?: string,
    @Query('limit') limit: number = 20,
  ) {
    return this.marketplaceService.getMyListings(user.userId, status, cursor, limit);
  }

  @Get('favorites')
  @ApiOperation({ summary: "Get current user's favorite listings" })
  @ApiResponse({ status: 200, description: 'Favorite listings' })
  async getMyFavorites(
    @CurrentUser() user: CurrentUserPayload,
    @Query('cursor') cursor?: string,
    @Query('limit') limit: number = 20,
  ) {
    return this.marketplaceService.getMyFavorites(user.userId, cursor, limit);
  }

  @Get('listings/favorites')
  @ApiOperation({ summary: "Get current user's favorite listings (alias)" })
  @ApiResponse({ status: 200, description: 'Favorite listings' })
  async getMyListingsFavorites(
    @CurrentUser() user: CurrentUserPayload,
    @Query('cursor') cursor?: string,
    @Query('limit') limit: number = 20,
  ) {
    return this.marketplaceService.getMyFavorites(user.userId, cursor, limit);
  }

  @Get('listings/:id')
  @ApiOperation({ summary: 'Get marketplace listing detail by ID' })
  @ApiResponse({ status: 200, description: 'Listing details' })
  @ApiResponse({ status: 404, description: 'Listing not found' })
  async getListingById(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.marketplaceService.getListingById(id, user.userId);
  }

  @Patch('listings/:id')
  @ApiOperation({ summary: 'Update listing details (Owner only)' })
  @ApiResponse({ status: 200, description: 'Listing updated successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async updateListing(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateListingDto,
  ) {
    return this.marketplaceService.updateListing(id, user.userId, dto);
  }

  @Patch('listings/:id/status')
  @ApiOperation({ summary: 'Update listing lifecycle status (Owner only: active, sold, archived)' })
  @ApiResponse({ status: 200, description: 'Status updated successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async updateListingStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateListingStatusDto,
  ) {
    return this.marketplaceService.updateListingStatus(id, user.userId, dto.status);
  }

  @Delete('listings/:id')
  @ApiOperation({ summary: 'Delete/archive own listing (Owner only)' })
  @ApiResponse({ status: 200, description: 'Listing deleted successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async deleteListing(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.marketplaceService.deleteListing(id, user.userId);
  }

  @Post('listings/:id/favorite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Favorite a marketplace listing' })
  @ApiResponse({ status: 200, description: 'Listing favorited' })
  async favoriteListing(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.marketplaceService.toggleFavorite(id, user.userId, true);
  }

  @Delete('listings/:id/favorite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unfavorite a marketplace listing' })
  @ApiResponse({ status: 200, description: 'Listing unfavorited' })
  async unfavoriteListing(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.marketplaceService.toggleFavorite(id, user.userId, false);
  }

  @Post('listings/:id/report')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Report a marketplace listing for review' })
  @ApiResponse({ status: 200, description: 'Report accepted' })
  @ApiResponse({ status: 400, description: 'Cannot report own listing' })
  @ApiResponse({ status: 409, description: 'Already reported' })
  async reportListing(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateMarketplaceReportDto,
  ) {
    return this.marketplaceService.reportListing(id, user.userId, dto);
  }
}

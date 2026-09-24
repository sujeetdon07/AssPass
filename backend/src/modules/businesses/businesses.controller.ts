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
import { BusinessesService } from './services/businesses.service.js';
import { CreateBusinessDto } from './dto/create-business.dto.js';
import { UpdateBusinessDto } from './dto/update-business.dto.js';
import { UpdateBusinessStatusDto } from './dto/update-business-status.dto.js';
import { GetBusinessesQueryDto } from './dto/get-businesses-query.dto.js';
import { CreateBusinessReportDto } from './dto/create-business-report.dto.js';
import { BusinessStatus } from './entities/business.entity.js';

@ApiTags('businesses')
@Controller({ path: 'businesses', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('access-token')
export class BusinessesController {
  constructor(private readonly businessesService: BusinessesService) {}

  @Get('categories')
  @ApiOperation({ summary: 'Get all centralized business categories with descriptions' })
  @ApiResponse({ status: 200, description: 'List of business categories' })
  getCategories() {
    return this.businessesService.getCategories();
  }

  @Get('me')
  @ApiOperation({ summary: "Get current user's registered businesses" })
  @ApiResponse({ status: 200, description: 'User businesses list' })
  async getMyBusinesses(
    @CurrentUser() user: CurrentUserPayload,
    @Query('status') status?: BusinessStatus,
    @Query('cursor') cursor?: string,
    @Query('limit') limit: number = 20,
  ) {
    return this.businessesService.getMyBusinesses(user.userId, status, cursor, limit);
  }

  @Get()
  @ApiOperation({
    summary: 'Discover businesses with search, category filter, PostGIS radius, and pagination',
  })
  @ApiResponse({ status: 200, description: 'Paginated businesses discovery list' })
  async getBusinesses(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetBusinessesQueryDto,
  ) {
    return this.businessesService.getBusinesses(user.userId, query);
  }

  @Post()
  @ApiOperation({ summary: 'Register a new local business' })
  @ApiResponse({ status: 201, description: 'Business registered successfully' })
  async createBusiness(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateBusinessDto,
  ) {
    return this.businessesService.createBusiness(user.userId, dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get business details by ID' })
  @ApiResponse({ status: 200, description: 'Business details' })
  @ApiResponse({ status: 404, description: 'Business not found' })
  async getBusinessById(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.businessesService.getBusinessById(id, user.userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update business details (Owner only)' })
  @ApiResponse({ status: 200, description: 'Business updated successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async updateBusiness(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateBusinessDto,
  ) {
    return this.businessesService.updateBusiness(id, user.userId, dto);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Update business status (Owner only: active, inactive, archived)' })
  @ApiResponse({ status: 200, description: 'Status updated successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async updateBusinessStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateBusinessStatusDto,
  ) {
    return this.businessesService.updateBusinessStatus(id, user.userId, dto.status);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft delete business (Owner only)' })
  @ApiResponse({ status: 200, description: 'Business deleted successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async deleteBusiness(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.businessesService.deleteBusiness(id, user.userId);
  }

  @Post(':id/favorite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Favorite a business' })
  @ApiResponse({ status: 200, description: 'Business favorited' })
  async favoriteBusiness(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.businessesService.toggleFavorite(id, user.userId, true);
  }

  @Delete(':id/favorite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unfavorite a business' })
  @ApiResponse({ status: 200, description: 'Business unfavorited' })
  async unfavoriteBusiness(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.businessesService.toggleFavorite(id, user.userId, false);
  }

  @Post(':id/report')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Report a business for moderation review' })
  @ApiResponse({ status: 200, description: 'Report accepted' })
  @ApiResponse({ status: 400, description: 'Cannot report own business' })
  @ApiResponse({ status: 409, description: 'Already reported' })
  async reportBusiness(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateBusinessReportDto,
  ) {
    return this.businessesService.reportBusiness(id, user.userId, dto);
  }
}

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
import { ServicesService } from './services/services.service.js';
import { CreateServiceDto } from './dto/create-service.dto.js';
import { UpdateServiceDto } from './dto/update-service.dto.js';
import { UpdateServiceStatusDto } from './dto/update-service-status.dto.js';
import { GetServicesQueryDto } from './dto/get-services-query.dto.js';
import { CreateServiceReportDto } from './dto/create-service-report.dto.js';
import { ServiceStatus } from './entities/service-listing.entity.js';

@ApiTags('services')
@Controller({ path: 'services', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('access-token')
export class ServicesController {
  constructor(private readonly servicesService: ServicesService) {}

  @Get('categories')
  @ApiOperation({ summary: 'Get all centralized service categories with descriptions' })
  @ApiResponse({ status: 200, description: 'List of service categories' })
  getCategories() {
    return this.servicesService.getCategories();
  }

  @Get('me')
  @ApiOperation({ summary: "Get current user's registered service listings" })
  @ApiResponse({ status: 200, description: 'User services list' })
  async getMyServices(
    @CurrentUser() user: CurrentUserPayload,
    @Query('status') status?: ServiceStatus,
    @Query('cursor') cursor?: string,
    @Query('limit') limit: number = 20,
  ) {
    return this.servicesService.getMyServices(user.userId, status, cursor, limit);
  }

  @Get()
  @ApiOperation({
    summary: 'Discover local services with search, category, PostGIS radius, and pagination',
  })
  @ApiResponse({ status: 200, description: 'Paginated services discovery list' })
  async getServices(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: GetServicesQueryDto,
  ) {
    return this.servicesService.getServices(user.userId, query);
  }

  @Post()
  @ApiOperation({ summary: 'Register a new local service listing' })
  @ApiResponse({ status: 201, description: 'Service registered successfully' })
  async createService(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateServiceDto,
  ) {
    return this.servicesService.createService(user.userId, dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get service listing details by ID' })
  @ApiResponse({ status: 200, description: 'Service details' })
  @ApiResponse({ status: 404, description: 'Service not found' })
  async getServiceById(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.servicesService.getServiceById(id, user.userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update service listing (Owner only)' })
  @ApiResponse({ status: 200, description: 'Service updated successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async updateService(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateServiceDto,
  ) {
    return this.servicesService.updateService(id, user.userId, dto);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Update service status (Owner only: active, inactive, archived)' })
  @ApiResponse({ status: 200, description: 'Status updated successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async updateServiceStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateServiceStatusDto,
  ) {
    return this.servicesService.updateServiceStatus(id, user.userId, dto.status);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft delete service listing (Owner only)' })
  @ApiResponse({ status: 200, description: 'Service deleted successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden - not authorized' })
  async deleteService(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.servicesService.deleteService(id, user.userId);
  }

  @Post(':id/favorite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Favorite a service listing' })
  @ApiResponse({ status: 200, description: 'Service favorited' })
  async favoriteService(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.servicesService.toggleFavorite(id, user.userId, true);
  }

  @Delete(':id/favorite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unfavorite a service listing' })
  @ApiResponse({ status: 200, description: 'Service unfavorited' })
  async unfavoriteService(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
  ) {
    return this.servicesService.toggleFavorite(id, user.userId, false);
  }

  @Post(':id/report')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Report a service listing for moderation review' })
  @ApiResponse({ status: 200, description: 'Report accepted' })
  @ApiResponse({ status: 400, description: 'Cannot report own service' })
  @ApiResponse({ status: 409, description: 'Already reported' })
  async reportService(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateServiceReportDto,
  ) {
    return this.servicesService.reportService(id, user.userId, dto);
  }
}

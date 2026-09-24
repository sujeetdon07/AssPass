import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';
import { LocalitiesService } from './localities.service.js';

@ApiTags('localities')
@Controller('localities')
export class LocalitiesController {
  constructor(private readonly localitiesService: LocalitiesService) {}

  @Get('search')
  @ApiOperation({ summary: 'Search localities by name, city, or postal code' })
  @ApiQuery({ name: 'query', required: false, description: 'Search term (e.g. Indiranagar, Mumbai, Meerut)' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Matching locality items' })
  search(@Query('query') query?: string, @Query('limit') limit?: number) {
    const parsedLimit = limit ? Math.min(Math.max(Number(limit), 1), 50) : 10;
    return this.localitiesService.search(query, parsedLimit);
  }

  @Get('popular')
  @ApiOperation({ summary: 'List popular localities across Indian metro cities' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Popular localities' })
  getPopular(@Query('limit') limit?: number) {
    const parsedLimit = limit ? Math.min(Math.max(Number(limit), 1), 50) : 10;
    return this.localitiesService.getPopular(parsedLimit);
  }
}

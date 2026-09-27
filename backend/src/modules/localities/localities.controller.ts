import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';
import { LocalitiesService } from './localities.service.js';

@ApiTags('localities')
@Controller('localities')
export class LocalitiesController {
  constructor(private readonly localitiesService: LocalitiesService) {}

  @Get('search')
  @ApiOperation({ summary: 'Search localities by name, city, or postal code' })
  @ApiQuery({ name: 'query', required: false, description: 'Search term (e.g. Indiranagar, Noida, Sasaram)' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Matching locality items' })
  async search(@Query('query') query?: string, @Query('limit') limit?: number) {
    const parsedLimit = limit ? Math.min(Math.max(Number(limit), 1), 50) : 10;
    return this.localitiesService.search(query, parsedLimit);
  }

  @Get('reverse')
  @ApiOperation({ summary: 'Reverse geocode GPS coordinates to an Indian locality' })
  @ApiQuery({ name: 'lat', required: true, type: Number, description: 'Latitude coordinate' })
  @ApiQuery({ name: 'lon', required: true, type: Number, description: 'Longitude coordinate' })
  @ApiResponse({ status: 200, description: 'Resolved locality item or null' })
  async reverse(@Query('lat') lat: number, @Query('lon') lon: number) {
    return this.localitiesService.reverseGeocode(Number(lat), Number(lon));
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

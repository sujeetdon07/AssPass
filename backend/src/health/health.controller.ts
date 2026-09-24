import { Controller, Get, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';

import { HealthService, HealthStatus } from './health.service.js';

@ApiTags('health')
@Controller({
  path: 'health',
  version: '1',
})
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  /**
   * GET /api/v1/health
   *
   * Returns the operational status of all backend dependencies.
   * This endpoint does NOT require authentication.
   * This endpoint does NOT expose secrets.
   */
  @Get()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Check backend service health' })
  @ApiResponse({
    status: 200,
    description: 'Health status of all services',
    schema: {
      example: {
        success: true,
        service: 'aaspaas-api',
        environment: 'development',
        timestamp: '2025-01-01T00:00:00.000Z',
        database: 'connected',
        redis: 'connected',
      },
    },
  })
  async check(): Promise<HealthStatus> {
    return this.healthService.check();
  }
}

import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

import { RedisService } from '../database/redis.service.js';

export interface HealthStatus {
  success: boolean;
  service: string;
  environment: string;
  timestamp: string;
  database: 'connected' | 'disconnected';
  redis: 'connected' | 'disconnected';
}

/**
 * Checks the health of all backend dependencies.
 *
 * Each check is performed independently so that a single service
 * failure does not hide the status of other services.
 */
@Injectable()
export class HealthService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly redisService: RedisService,
  ) {}

  async check(): Promise<HealthStatus> {
    const [databaseStatus, redisStatus] = await Promise.all([
      this.checkDatabase(),
      this.checkRedis(),
    ]);

    const allHealthy = databaseStatus === 'connected' && redisStatus === 'connected';

    return {
      success: allHealthy,
      service: 'aaspaas-api',
      environment: process.env['NODE_ENV'] ?? 'development',
      timestamp: new Date().toISOString(),
      database: databaseStatus,
      redis: redisStatus,
    };
  }

  private async checkDatabase(): Promise<'connected' | 'disconnected'> {
    try {
      // Run a minimal query to verify the connection is alive.
      await this.dataSource.query('SELECT 1');
      return 'connected';
    } catch {
      return 'disconnected';
    }
  }

  private async checkRedis(): Promise<'connected' | 'disconnected'> {
    try {
      const response = await this.redisService.ping();
      return response === 'PONG' ? 'connected' : 'disconnected';
    } catch {
      return 'disconnected';
    }
  }
}

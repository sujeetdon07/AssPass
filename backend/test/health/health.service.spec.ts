import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { DataSource } from 'typeorm';

import { HealthService } from '../../src/health/health.service.js';
import { RedisService } from '../../src/database/redis.service.js';

describe('HealthService', () => {
  let service: HealthService;
  let mockDataSource: Partial<DataSource>;
  let mockRedisService: Partial<RedisService>;

  beforeEach(async () => {
    mockDataSource = {
      query: vi.fn().mockResolvedValue([{ '?column?': 1 }]),
    };

    mockRedisService = {
      ping: vi.fn().mockResolvedValue('PONG'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HealthService,
        { provide: DataSource, useValue: mockDataSource },
        { provide: RedisService, useValue: mockRedisService },
      ],
    }).compile();

    service = module.get<HealthService>(HealthService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('returns success=true when both services are connected', async () => {
    const result = await service.check();

    expect(result.success).toBe(true);
    expect(result.database).toBe('connected');
    expect(result.redis).toBe('connected');
    expect(result.service).toBe('aaspaas-api');
    expect(result.timestamp).toBeDefined();
  });

  it('returns database=disconnected when database is unreachable', async () => {
    mockDataSource.query = vi.fn().mockRejectedValue(new Error('Connection refused'));

    const result = await service.check();

    expect(result.success).toBe(false);
    expect(result.database).toBe('disconnected');
    expect(result.redis).toBe('connected');
  });

  it('returns redis=disconnected when Redis is unreachable', async () => {
    mockRedisService.ping = vi.fn().mockRejectedValue(new Error('Redis unavailable'));

    const result = await service.check();

    expect(result.success).toBe(false);
    expect(result.database).toBe('connected');
    expect(result.redis).toBe('disconnected');
  });

  it('returns success=false when both services are down', async () => {
    mockDataSource.query = vi.fn().mockRejectedValue(new Error('DB down'));
    mockRedisService.ping = vi.fn().mockRejectedValue(new Error('Redis down'));

    const result = await service.check();

    expect(result.success).toBe(false);
    expect(result.database).toBe('disconnected');
    expect(result.redis).toBe('disconnected');
  });

  it('returns success=false when Redis returns non-PONG response', async () => {
    mockRedisService.ping = vi.fn().mockResolvedValue('ERROR');

    const result = await service.check();

    expect(result.redis).toBe('disconnected');
    expect(result.success).toBe(false);
  });
});

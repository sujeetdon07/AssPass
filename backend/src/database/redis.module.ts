import { Module, Global } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { Redis } from 'ioredis';

import { RedisService } from './redis.service.js';
import { REDIS_CLIENT } from './redis.constants.js';

export { REDIS_CLIENT };

/**
 * Global Redis module.
 *
 * Provides:
 * - The raw IORedis client (injected via REDIS_CLIENT token)
 * - The RedisService abstraction (injected via RedisService)
 *
 * Marked @Global so it is available in all feature modules without
 * re-importing.
 */
@Global()
@Module({
  imports: [ConfigModule],
  providers: [
    {
      provide: REDIS_CLIENT,
      inject: [ConfigService],
      useFactory: (configService: ConfigService): Redis => {
        const client = new Redis({
          host: configService.get<string>('REDIS_HOST', 'localhost'),
          port: configService.get<number>('REDIS_PORT', 6379),
          password: configService.get<string>('REDIS_PASSWORD'),
          retryStrategy: (times: number) => {
            // Retry with exponential backoff, up to 30 seconds.
            const delay = Math.min(times * 500, 30000);
            return delay;
          },
          maxRetriesPerRequest: 3,
          lazyConnect: true,
        });

        client.on('connect', () => {
          console.log('[Redis] Connected successfully.');
        });

        client.on('error', (error: Error) => {
          // Log the error type but never log sensitive data.
          console.error('[Redis] Connection error:', error.message);
        });

        return client;
      },
    },
    RedisService,
  ],
  exports: [REDIS_CLIENT, RedisService],
})
export class RedisModule {}

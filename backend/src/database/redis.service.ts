import { Injectable, Inject } from '@nestjs/common';
import { Redis } from 'ioredis';

import { REDIS_CLIENT } from './redis.constants.js';

/**
 * Redis service abstraction.
 *
 * Wraps common Redis operations with typed methods.
 * Use this rather than injecting the raw client directly
 * to allow easy mocking in tests.
 */
@Injectable()
export class RedisService {
  constructor(@Inject(REDIS_CLIENT) private readonly client: Redis) {}

  /**
   * Set a string value with an optional TTL in seconds.
   */
  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (ttlSeconds !== undefined) {
      await this.client.set(key, value, 'EX', ttlSeconds);
    } else {
      await this.client.set(key, value);
    }
  }

  /**
   * Get a string value. Returns null if the key does not exist.
   */
  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  /**
   * Delete one or more keys. Returns the number of keys deleted.
   */
  async del(...keys: string[]): Promise<number> {
    return this.client.del(...keys);
  }

  /**
   * Check if a key exists.
   */
  async exists(key: string): Promise<boolean> {
    const result = await this.client.exists(key);
    return result === 1;
  }

  /**
   * Set a key to expire in the given number of seconds.
   */
  async expire(key: string, ttlSeconds: number): Promise<void> {
    await this.client.expire(key, ttlSeconds);
  }

  /**
   * Increment the integer value of a key by one.
   */
  async incr(key: string): Promise<number> {
    return this.client.incr(key);
  }

  /**
   * Get the remaining TTL for a key in seconds.
   * Returns -2 if the key does not exist, -1 if no TTL is set.
   */
  async ttl(key: string): Promise<number> {
    return this.client.ttl(key);
  }

  /**
   * Ping the Redis server.
   * Returns 'PONG' if the connection is alive.
   */
  async ping(): Promise<string> {
    return this.client.ping();
  }

  /**
   * Get the underlying IORedis client for advanced operations.
   * Prefer using the typed methods above when possible.
   */
  getClient(): Redis {
    return this.client;
  }
}

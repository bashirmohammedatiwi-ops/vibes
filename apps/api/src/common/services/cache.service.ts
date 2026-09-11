import { Injectable, Logger } from '@nestjs/common';
import { RedisService } from '../../redis/redis.service';

/**
 * Thin JSON cache wrapper around the shared Redis connection. Failures are
 * swallowed and logged — caching must never break a request.
 */
@Injectable()
export class CacheService {
  private readonly logger = new Logger(CacheService.name);

  constructor(private readonly redis: RedisService) {}

  async get<T>(key: string): Promise<T | null> {
    try {
      const raw = await this.redis.get(key);
      return raw ? (JSON.parse(raw) as T) : null;
    } catch (err) {
      this.logger.warn(`cache get failed for "${key}": ${(err as Error).message}`);
      return null;
    }
  }

  async set(key: string, value: unknown, ttlSeconds: number): Promise<void> {
    try {
      await this.redis.set(key, JSON.stringify(value), 'EX', ttlSeconds);
    } catch (err) {
      this.logger.warn(`cache set failed for "${key}": ${(err as Error).message}`);
    }
  }

  async del(...keys: string[]): Promise<void> {
    if (!keys.length) return;
    try {
      await this.redis.del(...keys);
    } catch (err) {
      this.logger.warn(`cache del failed: ${(err as Error).message}`);
    }
  }

  /** Loads from cache, or computes + stores on miss. */
  async getOrSet<T>(key: string, ttlSeconds: number, loader: () => Promise<T>): Promise<T> {
    const cached = await this.get<T>(key);
    if (cached !== null) return cached;
    const fresh = await loader();
    await this.set(key, fresh, ttlSeconds);
    return fresh;
  }

  /** Deletes every key under a prefix using non-blocking SCAN. */
  async invalidatePrefix(prefix: string): Promise<void> {
    try {
      const keys: string[] = [];
      const stream = this.redis.scanStream({ match: `${prefix}*`, count: 200 });
      await new Promise<void>((resolve, reject) => {
        stream.on('data', (chunk: string[]) => keys.push(...chunk));
        stream.on('end', resolve);
        stream.on('error', reject);
      });
      if (keys.length) await this.redis.del(...keys);
    } catch (err) {
      this.logger.warn(`cache invalidate failed for "${prefix}": ${(err as Error).message}`);
    }
  }

  /** Stable cache key from a query/filter object (order-independent). */
  static keyFrom(namespace: string, params: Record<string, unknown> = {}): string {
    const sorted = Object.keys(params)
      .filter((k) => params[k] !== undefined && params[k] !== null && params[k] !== '')
      .sort()
      .map((k) => `${k}=${params[k]}`)
      .join('&');
    return `cache:${namespace}:${sorted || 'all'}`;
  }
}

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { HttpException } from '@nestjs/common';
import { NearbyService } from '../../src/modules/nearby/services/nearby.service.js';
import { PostCategory } from '../../src/modules/feed/entities/post.entity.js';

describe('NearbyService', () => {
  let service: NearbyService;
  let mockPostRepo: any;
  let mockRedisService: any;
  let mockQueryBuilder: any;

  const mockRows = [
    {
      id: 'post-near-1',
      authorId: 'usr-1',
      content: 'Power issue in 4th block',
      category: PostCategory.ALERT,
      countryCode: 'IN',
      state: 'Karnataka',
      district: 'Bengaluru Urban',
      city: 'Bengaluru',
      locality: 'Indiranagar',
      neighborhood: 'Defence Colony',
      likeCount: 5,
      commentCount: 2,
      createdAt: '2026-09-22T12:00:00.000Z',
      updatedAt: '2026-09-22T12:00:00.000Z',
      author_id: 'usr-1',
      author_displayName: 'Neighbor Aakash',
      author_avatarUrl: null,
      author_locality: 'Indiranagar',
      author_city: 'Bengaluru',
      currentUserLiked: 'true',
      distance_meters: '420',
    },
    {
      id: 'post-near-2',
      authorId: 'usr-2',
      content: 'Any good plumber recommendations?',
      category: PostCategory.QUESTION,
      countryCode: 'IN',
      state: 'Karnataka',
      district: 'Bengaluru Urban',
      city: 'Bengaluru',
      locality: 'Koramangala',
      neighborhood: '5th Block',
      likeCount: 1,
      commentCount: 0,
      createdAt: '2026-09-22T11:30:00.000Z',
      updatedAt: '2026-09-22T11:30:00.000Z',
      author_id: 'usr-2',
      author_displayName: 'Neighbor Priya',
      author_avatarUrl: null,
      author_locality: 'Koramangala',
      author_city: 'Bengaluru',
      currentUserLiked: 'false',
      distance_meters: '1450',
    },
  ];

  beforeEach(() => {
    mockQueryBuilder = {
      leftJoin: vi.fn().mockReturnThis(),
      select: vi.fn().mockReturnThis(),
      setParameters: vi.fn().mockReturnThis(),
      where: vi.fn().mockReturnThis(),
      andWhere: vi.fn().mockReturnThis(),
      orderBy: vi.fn().mockReturnThis(),
      addOrderBy: vi.fn().mockReturnThis(),
      limit: vi.fn().mockReturnThis(),
      getRawMany: vi.fn().mockResolvedValue(mockRows),
    };

    mockPostRepo = {
      createQueryBuilder: vi.fn().mockReturnValue(mockQueryBuilder),
    };

    mockRedisService = {
      get: vi.fn().mockResolvedValue(null),
      set: vi.fn().mockResolvedValue('OK'),
      ttl: vi.fn().mockResolvedValue(60),
      incr: vi.fn().mockResolvedValue(1),
      expire: vi.fn().mockResolvedValue(1),
      del: vi.fn().mockResolvedValue(1),
    };

    service = new NearbyService(mockPostRepo, mockRedisService);
  });

  it('queries nearby posts with ST_DWithin and calculates distances', async () => {
    const res = await service.getNearbyPosts('current-user-id', {
      latitude: 12.9784,
      longitude: 77.6408,
      radius: 5,
      limit: 20,
    });

    expect(mockPostRepo.createQueryBuilder).toHaveBeenCalledWith('post');
    expect(mockQueryBuilder.setParameters).toHaveBeenCalledWith({
      lng: 77.6408,
      lat: 12.9784,
      radiusMeters: 5000,
    });
    expect(mockQueryBuilder.where).toHaveBeenCalledWith('post.location IS NOT NULL');
    expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith('post.deletedAt IS NULL');
    expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
      'ST_DWithin(post.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :radiusMeters)',
    );

    expect(res.items.length).toBe(2);
    expect(res.items[0].id).toBe('post-near-1');
    expect(res.items[0].distance).toBe('400 m away');
    expect(res.items[0].currentUserLiked).toBe(true);
    expect(res.items[1].distance).toBe('1.4 km away');
  });

  it('guarantees location privacy: no raw coordinates or phone numbers in response', async () => {
    const res = await service.getNearbyPosts('current-user-id', {
      latitude: 12.9784,
      longitude: 77.6408,
    });

    for (const item of res.items) {
      expect((item as any).latitude).toBeUndefined();
      expect((item as any).longitude).toBeUndefined();
      expect((item as any).location).toBeUndefined();
      expect((item as any).phoneNumber).toBeUndefined();
      expect((item.author as any).phoneNumber).toBeUndefined();
      expect(typeof item.distance).toBe('string');
      expect(typeof item.distanceMeters).toBe('number');
    }
  });

  it('applies category filtering when category is supplied', async () => {
    await service.getNearbyPosts('current-user-id', {
      latitude: 12.9784,
      longitude: 77.6408,
      category: PostCategory.ALERT,
    });

    expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith('post.category = :category', {
      category: PostCategory.ALERT,
    });
  });

  it('handles cursor pagination and indicates hasMore when results exceed limit', async () => {
    mockQueryBuilder.getRawMany.mockResolvedValueOnce([
      mockRows[0],
      mockRows[1],
      { ...mockRows[0], id: 'post-near-3', distance_meters: '2500' },
    ]);

    const res = await service.getNearbyPosts('current-user-id', {
      latitude: 12.9784,
      longitude: 77.6408,
      limit: 2,
    });

    expect(res.items.length).toBe(2);
    expect(res.hasMore).toBe(true);
    expect(res.nextCursor).toBeDefined();

    // Verify decoded cursor token
    const decoded = Buffer.from(res.nextCursor!, 'base64').toString('utf8');
    expect(decoded).toContain('1450');
    expect(decoded).toContain('post-near-2');
  });

  it('enforces Redis rate limiting when user exceeds 60 searches per minute', async () => {
    mockRedisService.incr.mockResolvedValueOnce(61);

    await expect(
      service.getNearbyPosts('current-user-id', {
        latitude: 12.9784,
        longitude: 77.6408,
      }),
    ).rejects.toThrow(HttpException);
  });
});

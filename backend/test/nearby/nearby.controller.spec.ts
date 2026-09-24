import { describe, it, expect, beforeEach, vi } from 'vitest';
import { NearbyController } from '../../src/modules/nearby/nearby.controller.js';
import { NearbyService } from '../../src/modules/nearby/services/nearby.service.js';
import { CurrentUserPayload } from '../../src/modules/auth/decorators/current-user.decorator.js';
import { GetNearbyPostsDto } from '../../src/modules/nearby/dto/get-nearby-posts.dto.js';
import { PostCategory } from '../../src/modules/feed/entities/post.entity.js';

describe('NearbyController', () => {
  let controller: NearbyController;
  let mockNearbyService: Partial<NearbyService>;

  const mockUser: CurrentUserPayload = {
    userId: 'usr-123',
    sessionId: 'session-123',
    phoneNumber: '+919876543210',
    onboarding: true,
  };

  beforeEach(() => {
    mockNearbyService = {
      getNearbyPosts: vi.fn().mockResolvedValue({
        items: [],
        nextCursor: null,
        hasMore: false,
        radiusKm: 5,
      }),
    };

    controller = new NearbyController(mockNearbyService as NearbyService);
  });

  it('delegates to NearbyService.getNearbyPosts with user ID and query', async () => {
    const query: GetNearbyPostsDto = {
      latitude: 12.9784,
      longitude: 77.6408,
      radius: 5,
      category: PostCategory.ALERT,
      limit: 20,
    };

    const res = await controller.getNearbyPosts(mockUser, query);

    expect(mockNearbyService.getNearbyPosts).toHaveBeenCalledWith('usr-123', query);
    expect(res).toBeDefined();
    expect(res.radiusKm).toBe(5);
  });
});

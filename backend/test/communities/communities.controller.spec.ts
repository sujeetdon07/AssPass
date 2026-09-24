import { describe, it, expect, beforeEach, vi } from 'vitest';
import { CommunitiesController } from '../../src/modules/communities/communities.controller.js';
import { CommunitiesService } from '../../src/modules/communities/services/communities.service.js';
import { CurrentUserPayload } from '../../src/modules/auth/decorators/current-user.decorator.js';
import { CommunityCategory, CommunityVisibility } from '../../src/modules/communities/entities/community.entity.js';
import { CommunityRole } from '../../src/modules/communities/entities/community-member.entity.js';
import { PostCategory } from '../../src/modules/feed/entities/post.entity.js';
import { ReportReason } from '../../src/modules/feed/entities/report.entity.js';

describe('CommunitiesController', () => {
  let controller: CommunitiesController;
  let mockService: any;

  const mockUser: CurrentUserPayload = {
    userId: 'usr-123',
    sessionId: 'session-123',
    phoneNumber: '+919876543210',
    onboarding: true,
  };

  beforeEach(() => {
    mockService = {
      getCommunities: vi.fn().mockResolvedValue({ communities: [], hasMore: false }),
      createCommunity: vi.fn().mockResolvedValue({ id: 'comm-123', name: 'Test Community' }),
      getCommunityById: vi.fn().mockResolvedValue({ id: 'comm-123', name: 'Test Community' }),
      updateCommunity: vi.fn().mockResolvedValue({ id: 'comm-123', name: 'Updated Community' }),
      joinCommunity: vi.fn().mockResolvedValue({ message: 'Joined', role: CommunityRole.MEMBER }),
      leaveCommunity: vi.fn().mockResolvedValue({ message: 'Left' }),
      getMembership: vi.fn().mockResolvedValue({ isMember: true, role: CommunityRole.MEMBER }),
      getMembers: vi.fn().mockResolvedValue({ members: [], hasMore: false }),
      getCommunityPosts: vi.fn().mockResolvedValue({ posts: [], hasMore: false }),
      createCommunityPost: vi.fn().mockResolvedValue({ id: 'post-123', content: 'Test post' }),
      reportCommunity: vi.fn().mockResolvedValue({ message: 'Reported' }),
    };

    controller = new CommunitiesController(mockService as CommunitiesService);
  });

  it('delegates getCommunities to CommunitiesService', async () => {
    const res = await controller.getCommunities(mockUser, { limit: 10 });
    expect(mockService.getCommunities).toHaveBeenCalledWith('usr-123', { limit: 10 });
    expect(res).toBeDefined();
  });

  it('delegates createCommunity to CommunitiesService', async () => {
    const dto = {
      name: 'Indiranagar Club',
      description: 'A local neighborhood group.',
      category: CommunityCategory.NEIGHBORHOOD,
      visibility: CommunityVisibility.PUBLIC,
    };
    const res = await controller.createCommunity(mockUser, dto);
    expect(mockService.createCommunity).toHaveBeenCalledWith('usr-123', dto);
    expect(res.id).toBe('comm-123');
  });

  it('delegates getCommunityById to CommunitiesService', async () => {
    const res = await controller.getCommunityById('comm-123', mockUser);
    expect(mockService.getCommunityById).toHaveBeenCalledWith('comm-123', 'usr-123');
    expect(res.id).toBe('comm-123');
  });

  it('delegates joinCommunity to CommunitiesService', async () => {
    const res = await controller.joinCommunity('comm-123', mockUser);
    expect(mockService.joinCommunity).toHaveBeenCalledWith('comm-123', 'usr-123');
    expect(res.message).toBe('Joined');
  });

  it('delegates leaveCommunity to CommunitiesService', async () => {
    const res = await controller.leaveCommunity('comm-123', mockUser);
    expect(mockService.leaveCommunity).toHaveBeenCalledWith('comm-123', 'usr-123');
    expect(res.message).toBe('Left');
  });

  it('delegates getMembers to CommunitiesService', async () => {
    const res = await controller.getMembers('comm-123', mockUser, undefined, 20);
    expect(mockService.getMembers).toHaveBeenCalledWith('comm-123', 'usr-123', 20, undefined);
    expect(res).toBeDefined();
  });

  it('delegates getCommunityPosts to CommunitiesService', async () => {
    const res = await controller.getCommunityPosts('comm-123', mockUser, undefined, 20);
    expect(mockService.getCommunityPosts).toHaveBeenCalledWith('comm-123', 'usr-123', 20, undefined);
    expect(res).toBeDefined();
  });

  it('delegates createCommunityPost to CommunitiesService', async () => {
    const dto = { content: 'Community post message', category: PostCategory.GENERAL };
    const res = await controller.createCommunityPost('comm-123', mockUser, dto);
    expect(mockService.createCommunityPost).toHaveBeenCalledWith('comm-123', 'usr-123', dto);
    expect(res.id).toBe('post-123');
  });

  it('delegates reportCommunity to CommunitiesService', async () => {
    const dto = { reason: ReportReason.SPAM, details: 'Spam report' };
    const res = await controller.reportCommunity('comm-123', mockUser, dto);
    expect(mockService.reportCommunity).toHaveBeenCalledWith('comm-123', 'usr-123', dto);
    expect(res.message).toBe('Reported');
  });
});

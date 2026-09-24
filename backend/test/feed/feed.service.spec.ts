import { describe, it, expect, beforeEach, vi } from 'vitest';
import { NotFoundException, ForbiddenException, HttpException } from '@nestjs/common';
import { FeedService } from '../../src/modules/feed/services/feed.service.js';
import { Post, PostCategory } from '../../src/modules/feed/entities/post.entity.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';
import { FeedScope } from '../../src/modules/feed/dto/get-feed-query.dto.js';

describe('FeedService', () => {
  let service: FeedService;
  let mockPostRepo: any;
  let mockUserRepo: any;
  let mockRedisService: any;

  const mockAuthor: User = {
    id: 'usr-author-1',
    phoneNumber: '+919876543210',
    displayName: 'Test Neighbor',
    avatarUrl: null,
    accountStatus: UserStatus.ACTIVE,
    onboardingCompleted: true,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: 'Defence Colony',
    createdAt: new Date(),
    updatedAt: new Date(),
    sessions: [],
  };

  const mockPost: Post = {
    id: 'post-1',
    authorId: mockAuthor.id,
    author: mockAuthor,
    content: 'Community alert: Road maintenance on 100ft road.',
    category: PostCategory.ALERT,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: '100ft road',
    likeCount: 2,
    commentCount: 1,
    reactions: [],
    comments: [],
    createdAt: new Date('2026-09-22T10:00:00.000Z'),
    updatedAt: new Date('2026-09-22T10:00:00.000Z'),
    deletedAt: null,
  };

  beforeEach(() => {
    mockPostRepo = {
      findOne: vi.fn(),
      save: vi.fn(),
      create: vi.fn((data: any) => ({ ...data, id: 'post-new-1', createdAt: new Date(), updatedAt: new Date() })),
      softDelete: vi.fn(),
      createQueryBuilder: vi.fn(),
      query: vi.fn().mockResolvedValue([]),
    };

    mockUserRepo = {
      findOne: vi.fn(),
    };

    mockRedisService = {
      get: vi.fn().mockResolvedValue(null),
      set: vi.fn().mockResolvedValue('OK'),
      ttl: vi.fn().mockResolvedValue(600),
    };

    service = new FeedService(mockPostRepo, mockUserRepo, mockRedisService);
  });

  describe('createPost', () => {
    it('creates a post with inherited locality and default like/comment counts', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      mockPostRepo.save.mockImplementation((p: any) => Promise.resolve(p));

      const result = await service.createPost(mockAuthor.id, {
        content: 'New park opened in Defence Colony!',
        category: PostCategory.ANNOUNCEMENT,
      });

      expect(result.content).toBe('New park opened in Defence Colony!');
      expect(result.category).toBe(PostCategory.ANNOUNCEMENT);
      expect(result.city).toBe('Bengaluru');
      expect(result.locality).toBe('Indiranagar');
      expect(result.likeCount).toBe(0);
      expect(result.commentCount).toBe(0);
      expect(result.isOwnPost).toBe(true);
      expect(mockPostRepo.save).toHaveBeenCalled();
    });

    it('rejects post creation if rate limit is exceeded', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      mockRedisService.get.mockResolvedValue('10'); // 10 posts already in window

      await expect(
        service.createPost(mockAuthor.id, { content: 'Another post' }),
      ).rejects.toThrow(HttpException);
    });

    it('throws NotFoundException if user does not exist', async () => {
      mockUserRepo.findOne.mockResolvedValue(null);

      await expect(
        service.createPost('non-existent-user', { content: 'Hello' }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('getFeed', () => {
    it('returns paginated posts with nextCursor and currentUserLiked flag', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);

      const mockQb = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        leftJoin: vi.fn().mockReturnThis(),
        addSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        addOrderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [mockPost],
          raw: [{ currentUserLiked: true }],
        }),
      };
      mockPostRepo.createQueryBuilder.mockReturnValue(mockQb);

      const result = await service.getFeed(mockAuthor.id, {
        limit: 10,
        scope: FeedScope.LOCAL,
      });

      expect(result.posts).toHaveLength(1);
      expect(result.posts[0].id).toBe('post-1');
      expect(result.posts[0].currentUserLiked).toBe(true);
      expect(result.hasMore).toBe(false);
    });
  });

  describe('updatePost', () => {
    it('updates post content when requested by the author', async () => {
      mockPostRepo.findOne.mockResolvedValue({ ...mockPost });
      mockPostRepo.save.mockImplementation((p: any) => Promise.resolve(p));

      // Mock getPostById call
      const mockQb = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        leftJoin: vi.fn().mockReturnThis(),
        addSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [{ ...mockPost, content: 'Updated content' }],
          raw: [{ currentUserLiked: false }],
        }),
      };
      mockPostRepo.createQueryBuilder.mockReturnValue(mockQb);

      const result = await service.updatePost('post-1', mockAuthor.id, {
        content: 'Updated content',
      });

      expect(result.content).toBe('Updated content');
    });

    it('throws ForbiddenException if a user tries to edit another user post', async () => {
      mockPostRepo.findOne.mockResolvedValue({ ...mockPost });

      await expect(
        service.updatePost('post-1', 'other-user-id', { content: 'Hacked' }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('deletePost', () => {
    it('soft deletes post when requested by author', async () => {
      mockPostRepo.findOne.mockResolvedValue({ ...mockPost });

      await service.deletePost('post-1', mockAuthor.id);
      expect(mockPostRepo.softDelete).toHaveBeenCalledWith({ id: 'post-1' });
    });

    it('throws ForbiddenException when non-author attempts deletion', async () => {
      mockPostRepo.findOne.mockResolvedValue({ ...mockPost });

      await expect(
        service.deletePost('post-1', 'other-user-id'),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { NotFoundException, ForbiddenException, HttpException } from '@nestjs/common';
import { FeedService } from '../../src/modules/feed/services/feed.service.js';
import { Post, PostCategory } from '../../src/modules/feed/entities/post.entity.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';
import { FeedScope } from '../../src/modules/feed/dto/get-feed-query.dto.js';

describe('FeedService', () => {
  let service: FeedService;
  let mockPostRepo: any;
  let mockPostMentionRepo: any;
  let mockUserRepo: any;
  let mockRedisService: any;
  let mockNotificationsService: any;

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

  let mockPostImageRepo: any;

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
      find: vi.fn().mockResolvedValue([]),
    };

    mockPostMentionRepo = {
      find: vi.fn().mockResolvedValue([]),
      create: vi.fn((data: any) => data),
      save: vi.fn().mockResolvedValue([]),
      delete: vi.fn().mockResolvedValue({ affected: 0 }),
    };

    mockPostImageRepo = {
      find: vi.fn().mockResolvedValue([]),
      create: vi.fn((data: any) => ({ ...data, id: 'img-new-1', createdAt: new Date() })),
      save: vi.fn((data: any) =>
        Promise.resolve(
          Array.isArray(data)
            ? data.map((d: any, i: number) => ({ ...d, id: `img-${i + 1}` }))
            : { ...data, id: 'img-1' },
        ),
      ),
      delete: vi.fn().mockResolvedValue({ affected: 0 }),
    };

    mockNotificationsService = {
      createAndSend: vi.fn().mockResolvedValue(null),
    };

    mockRedisService = {
      get: vi.fn().mockResolvedValue(null),
      set: vi.fn().mockResolvedValue('OK'),
      ttl: vi.fn().mockResolvedValue(600),
      incr: vi.fn().mockResolvedValue(1),
      expire: vi.fn().mockResolvedValue(1),
      del: vi.fn().mockResolvedValue(1),
    };

    service = new FeedService(
      mockPostRepo,
      mockPostMentionRepo,
      mockPostImageRepo,
      mockUserRepo,
      mockRedisService,
      mockNotificationsService,
    );
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
      mockRedisService.incr.mockResolvedValue(11); // 10 posts already in window

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

    it('creates a post with image attachments and persists image metadata with sortOrder', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      mockPostRepo.save.mockImplementation((p: any) => Promise.resolve(p));

      const result = await service.createPost(mockAuthor.id, {
        content: 'Check out the new community garden!',
        category: PostCategory.GENERAL,
        images: [
          {
            url: 'http://localhost:3000/api/v1/media/files/img_garden1.webp',
            thumbnailUrl: 'http://localhost:3000/api/v1/media/files/thumb_garden1.webp',
            mediumUrl: 'http://localhost:3000/api/v1/media/files/med_garden1.webp',
            width: 1920,
            height: 1080,
            mimeType: 'image/webp',
            size: 200000,
            sortOrder: 0,
          },
          {
            url: 'http://localhost:3000/api/v1/media/files/img_garden2.webp',
            thumbnailUrl: 'http://localhost:3000/api/v1/media/files/thumb_garden2.webp',
            width: 1200,
            height: 800,
            mimeType: 'image/webp',
            size: 150000,
            sortOrder: 1,
          },
        ],
      });

      expect(result.content).toBe('Check out the new community garden!');
      expect(result.images).toHaveLength(2);
      expect(result.images![0].url).toContain('img_garden1.webp');
      expect(result.images![0].sortOrder).toBe(0);
      expect(result.images![1].url).toContain('img_garden2.webp');
      expect(result.images![1].sortOrder).toBe(1);
      expect(mockPostImageRepo.save).toHaveBeenCalled();
    });

    it('rejects post creation if images exceed maximum limit of 4', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      const fiveImages = Array.from({ length: 5 }, (_, i) => ({
        url: `http://localhost:3000/api/v1/media/files/img_${i}.webp`,
        thumbnailUrl: `http://localhost:3000/api/v1/media/files/thumb_${i}.webp`,
      }));

      await expect(
        service.createPost(mockAuthor.id, {
          content: 'Too many images',
          images: fiveImages,
        }),
      ).rejects.toThrow('A post cannot contain more than 4 images.');
    });

    it('rejects post creation if an image has invalid URL protocol', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);

      await expect(
        service.createPost(mockAuthor.id, {
          content: 'Unsafe image',
          images: [
            {
              url: 'javascript:alert(1)',
              thumbnailUrl: 'http://localhost:3000/api/v1/media/files/thumb.webp',
            },
          ],
        }),
      ).rejects.toThrow();
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

    it('returns post images attached to posts in getFeed', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      mockPostImageRepo.find.mockResolvedValue([
        {
          id: 'img-1',
          postId: 'post-1',
          url: 'http://localhost:3000/api/v1/media/files/img_1.webp',
          thumbnailUrl: 'http://localhost:3000/api/v1/media/files/thumb_1.webp',
          mediumUrl: 'http://localhost:3000/api/v1/media/files/med_1.webp',
          width: 800,
          height: 600,
          mimeType: 'image/webp',
          size: 120000,
          sortOrder: 0,
        },
      ]);

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
          raw: [{ currentUserLiked: false }],
        }),
      };
      mockPostRepo.createQueryBuilder.mockReturnValue(mockQb);

      const result = await service.getFeed(mockAuthor.id, {
        limit: 10,
        scope: FeedScope.LOCAL,
      });

      expect(result.posts[0].images).toHaveLength(1);
      expect(result.posts[0].images![0].url).toContain('img_1.webp');
      expect(result.posts[0].images![0].thumbnailUrl).toContain('thumb_1.webp');
    });
  });

  describe('getPostById', () => {
    it('returns post details along with attached images in sort order', async () => {
      mockPostImageRepo.find.mockResolvedValue([
        {
          id: 'img-first',
          postId: 'post-1',
          url: 'http://localhost:3000/api/v1/media/files/img_first.webp',
          thumbnailUrl: 'http://localhost:3000/api/v1/media/files/thumb_first.webp',
          sortOrder: 0,
        },
        {
          id: 'img-second',
          postId: 'post-1',
          url: 'http://localhost:3000/api/v1/media/files/img_second.webp',
          thumbnailUrl: 'http://localhost:3000/api/v1/media/files/thumb_second.webp',
          sortOrder: 1,
        },
      ]);

      const mockQb = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        leftJoin: vi.fn().mockReturnThis(),
        addSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [mockPost],
          raw: [{ currentUserLiked: false }],
        }),
      };
      mockPostRepo.createQueryBuilder.mockReturnValue(mockQb);

      const result = await service.getPostById('post-1', mockAuthor.id);

      expect(result.id).toBe('post-1');
      expect(result.images).toHaveLength(2);
      expect(result.images![0].id).toBe('img-first');
      expect(result.images![1].id).toBe('img-second');
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

    it('updates attached images when images are provided in update DTO', async () => {
      mockPostRepo.findOne.mockResolvedValue({ ...mockPost });
      mockPostRepo.save.mockImplementation((p: any) => Promise.resolve(p));

      const mockQb = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        leftJoin: vi.fn().mockReturnThis(),
        addSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [{ ...mockPost, content: 'Updated with new image' }],
          raw: [{ currentUserLiked: false }],
        }),
      };
      mockPostRepo.createQueryBuilder.mockReturnValue(mockQb);

      await service.updatePost('post-1', mockAuthor.id, {
        content: 'Updated with new image',
        images: [
          {
            url: 'http://localhost:3000/api/v1/media/files/img_new.webp',
            thumbnailUrl: 'http://localhost:3000/api/v1/media/files/thumb_new.webp',
            sortOrder: 0,
          },
        ],
      });

      expect(mockPostImageRepo.delete).toHaveBeenCalledWith({ postId: 'post-1' });
      expect(mockPostImageRepo.save).toHaveBeenCalled();
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

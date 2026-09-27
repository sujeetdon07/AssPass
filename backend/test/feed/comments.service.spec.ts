import { describe, it, expect, beforeEach, vi } from 'vitest';
import { NotFoundException, ForbiddenException, HttpException } from '@nestjs/common';
import { CommentsService } from '../../src/modules/feed/services/comments.service.js';
import { Post, PostCategory } from '../../src/modules/feed/entities/post.entity.js';
import { Comment } from '../../src/modules/feed/entities/comment.entity.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';

describe('CommentsService', () => {
  let service: CommentsService;
  let mockCommentRepo: any;
  let mockPostRepo: any;
  let mockUserRepo: any;
  let mockRedisService: any;
  let mockDataSource: any;

  const mockUser: User = {
    id: 'usr-1',
    phoneNumber: '+919876543210',
    displayName: 'Priya Sharma',
    avatarUrl: null,
    accountStatus: UserStatus.ACTIVE,
    onboardingCompleted: true,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Koramangala',
    createdAt: new Date(),
    updatedAt: new Date(),
    sessions: [],
  };

  const mockPost: Post = {
    id: 'post-1',
    authorId: 'usr-author',
    author: null as any,
    content: 'Community discussion',
    category: PostCategory.GENERAL,
    countryCode: 'IN',
    likeCount: 0,
    commentCount: 2,
    reactions: [],
    comments: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockComment: Comment = {
    id: 'comment-1',
    postId: 'post-1',
    post: mockPost,
    authorId: mockUser.id,
    author: mockUser,
    content: 'Great initiative!',
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
  };

  beforeEach(() => {
    mockCommentRepo = {
      findOne: vi.fn(),
      softDelete: vi.fn(),
      createQueryBuilder: vi.fn(),
    };

    mockPostRepo = {
      findOne: vi.fn(),
    };

    mockUserRepo = {
      findOne: vi.fn(),
    };

    mockRedisService = {
      get: vi.fn().mockResolvedValue(null),
      set: vi.fn().mockResolvedValue('OK'),
      ttl: vi.fn().mockResolvedValue(600),
      incr: vi.fn().mockResolvedValue(1),
      expire: vi.fn().mockResolvedValue(1),
      del: vi.fn().mockResolvedValue(1),
    };

    mockDataSource = {
      transaction: vi.fn((cb: any) =>
        cb({
          create: vi.fn((entity: any, data: any) => ({ ...data, id: 'comment-new', createdAt: new Date(), updatedAt: new Date() })),
          save: vi.fn((comment: any) => Promise.resolve(comment)),
          increment: vi.fn(),
          decrement: vi.fn(),
          softDelete: mockCommentRepo.softDelete,
          findOne: vi.fn().mockResolvedValue({ ...mockPost, commentCount: 3 }),
          update: vi.fn(),
        }),
      ),
    };

    service = new CommentsService(
      mockCommentRepo,
      mockPostRepo,
      mockUserRepo,
      mockRedisService,
      mockDataSource,
    );
  });

  describe('createComment', () => {
    it('creates comment and increments post comment count', async () => {
      mockPostRepo.findOne.mockResolvedValue(mockPost);
      mockUserRepo.findOne.mockResolvedValue(mockUser);

      const result = await service.createComment('post-1', mockUser.id, {
        content: 'I will attend the meeting.',
      });

      expect(result.content).toBe('I will attend the meeting.');
      expect(result.author.displayName).toBe('Priya Sharma');
      expect(result.isOwnComment).toBe(true);
      expect(mockDataSource.transaction).toHaveBeenCalled();
    });

    it('rejects commenting if post does not exist', async () => {
      mockPostRepo.findOne.mockResolvedValue(null);

      await expect(
        service.createComment('non-existent', mockUser.id, { content: 'Hi' }),
      ).rejects.toThrow(NotFoundException);
    });

    it('enforces comment rate limiting', async () => {
      mockPostRepo.findOne.mockResolvedValue(mockPost);
      mockRedisService.incr.mockResolvedValue('31'); // Max rate limit reached (30)

      await expect(
        service.createComment('post-1', mockUser.id, { content: 'Another comment' }),
      ).rejects.toThrow(HttpException);
    });
  });

  describe('deleteComment', () => {
    it('allows author to delete own comment', async () => {
      mockCommentRepo.findOne.mockResolvedValue(mockComment);

      await service.deleteComment('comment-1', mockUser.id);
      expect(mockDataSource.transaction).toHaveBeenCalled();
    });

    it('throws ForbiddenException when another user attempts deletion', async () => {
      mockCommentRepo.findOne.mockResolvedValue(mockComment);

      await expect(
        service.deleteComment('comment-1', 'other-user'),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { NotFoundException } from '@nestjs/common';
import { ReactionsService } from '../../src/modules/feed/services/reactions.service.js';
import { Post, PostCategory } from '../../src/modules/feed/entities/post.entity.js';

describe('ReactionsService', () => {
  let service: ReactionsService;
  let mockPostRepo: any;
  let mockReactionRepo: any;
  let mockDataSource: any;

  const mockPost: Post = {
    id: 'post-1',
    authorId: 'usr-1',
    author: null as any,
    content: 'Community post',
    category: PostCategory.GENERAL,
    countryCode: 'IN',
    likeCount: 5,
    commentCount: 0,
    reactions: [],
    comments: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(() => {
    mockPostRepo = {
      findOne: vi.fn(),
      increment: vi.fn(),
      decrement: vi.fn(),
    };

    mockReactionRepo = {
      findOne: vi.fn(),
      create: vi.fn((data: any) => ({ ...data, id: 'rxn-1' })),
      save: vi.fn(),
      delete: vi.fn(),
    };

    mockDataSource = {
      transaction: vi.fn((cb: any) =>
        cb({
          create: mockReactionRepo.create,
          save: mockReactionRepo.save,
          delete: mockReactionRepo.delete,
          increment: mockPostRepo.increment,
          decrement: mockPostRepo.decrement,
          findOne: vi.fn().mockResolvedValue({ ...mockPost, likeCount: 6 }),
          update: vi.fn(),
        }),
      ),
    };

    service = new ReactionsService(mockPostRepo, mockReactionRepo, mockDataSource);
  });

  describe('likePost', () => {
    it('creates a like and increments like count', async () => {
      mockPostRepo.findOne.mockResolvedValue({ ...mockPost, likeCount: 5 });
      mockReactionRepo.findOne.mockResolvedValue(null); // not yet liked

      const result = await service.likePost('post-1', 'usr-2');

      expect(result.liked).toBe(true);
      expect(result.likeCount).toBe(6);
      expect(mockDataSource.transaction).toHaveBeenCalled();
    });

    it('is idempotent when user already liked the post', async () => {
      mockPostRepo.findOne.mockResolvedValue({ ...mockPost, likeCount: 5 });
      mockReactionRepo.findOne.mockResolvedValue({ id: 'existing-rxn' });

      const result = await service.likePost('post-1', 'usr-2');

      expect(result.liked).toBe(true);
      expect(result.likeCount).toBe(5);
      expect(mockDataSource.transaction).not.toHaveBeenCalled();
    });

    it('throws NotFoundException if post does not exist', async () => {
      mockPostRepo.findOne.mockResolvedValue(null);

      await expect(service.likePost('non-existent', 'usr-1')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('unlikePost', () => {
    it('removes the like and decrements like count', async () => {
      mockPostRepo.findOne.mockResolvedValue({ ...mockPost, likeCount: 5 });
      mockReactionRepo.findOne.mockResolvedValue({ id: 'existing-rxn' });

      mockDataSource.transaction.mockImplementation((cb: any) =>
        cb({
          delete: mockReactionRepo.delete,
          decrement: mockPostRepo.decrement,
          findOne: vi.fn().mockResolvedValue({ ...mockPost, likeCount: 4 }),
          update: vi.fn(),
        }),
      );

      const result = await service.unlikePost('post-1', 'usr-2');

      expect(result.liked).toBe(false);
      expect(result.likeCount).toBe(4);
    });

    it('is idempotent when user has not liked the post', async () => {
      mockPostRepo.findOne.mockResolvedValue({ ...mockPost, likeCount: 5 });
      mockReactionRepo.findOne.mockResolvedValue(null);

      const result = await service.unlikePost('post-1', 'usr-2');

      expect(result.liked).toBe(false);
      expect(result.likeCount).toBe(5);
      expect(mockDataSource.transaction).not.toHaveBeenCalled();
    });
  });
});

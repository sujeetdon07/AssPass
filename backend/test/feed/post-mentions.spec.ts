import { describe, it, expect, beforeEach, vi } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import { FeedService } from '../../src/modules/feed/services/feed.service.js';
import { Post, PostCategory } from '../../src/modules/feed/entities/post.entity.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';
import { NotificationType } from '../../src/modules/notifications/enums/notification-type.enum.js';
import { NotificationCategory } from '../../src/modules/notifications/enums/notification-category.enum.js';

describe('FeedService - Post Mentions', () => {
  let service: FeedService;
  let mockPostRepo: any;
  let mockPostMentionRepo: any;
  let mockUserRepo: any;
  let mockRedisService: any;
  let mockNotificationsService: any;

  const mockAuthor: User = {
    id: 'usr-author-1',
    phoneNumber: '+919876543210',
    username: 'author_user',
    displayName: 'Author Neighbor',
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

  const mockMentionedUser1: User = {
    id: 'usr-sujeet-uuid',
    phoneNumber: '+919876543211',
    username: 'sujeet',
    displayName: 'Sujeet Kumar',
    avatarUrl: 'https://cdn.aaspaas.app/avatars/sujeet.png',
    accountStatus: UserStatus.ACTIVE,
    onboardingCompleted: true,
    countryCode: 'IN',
    createdAt: new Date(),
    updatedAt: new Date(),
    sessions: [],
  };

  const mockMentionedUser2: User = {
    id: 'usr-suman-uuid',
    phoneNumber: '+919876543212',
    username: 'suman',
    displayName: 'Suman Sharma',
    avatarUrl: null,
    accountStatus: UserStatus.ACTIVE,
    onboardingCompleted: true,
    countryCode: 'IN',
    createdAt: new Date(),
    updatedAt: new Date(),
    sessions: [],
  };

  beforeEach(() => {
    mockPostRepo = {
      findOne: vi.fn(),
      save: vi.fn((p: any) => Promise.resolve({ ...p, id: p.id ?? 'post-new-1', createdAt: new Date(), updatedAt: new Date() })),
      create: vi.fn((data: any) => ({ ...data, id: 'post-new-1', createdAt: new Date(), updatedAt: new Date() })),
      softDelete: vi.fn(),
      createQueryBuilder: vi.fn(),
      query: vi.fn().mockResolvedValue([]),
    };

    mockUserRepo = {
      findOne: vi.fn(),
      find: vi.fn().mockResolvedValue([mockMentionedUser1, mockMentionedUser2, mockAuthor]),
    };

    mockPostMentionRepo = {
      find: vi.fn().mockResolvedValue([]),
      create: vi.fn((data: any) => data),
      save: vi.fn((data: any) => Promise.resolve(data)),
      delete: vi.fn().mockResolvedValue({ affected: 0 }),
    };

    mockNotificationsService = {
      createAndSend: vi.fn().mockResolvedValue({ id: 'notif-1' }),
    };

    mockRedisService = {
      get: vi.fn().mockResolvedValue(null),
      set: vi.fn().mockResolvedValue('OK'),
      ttl: vi.fn().mockResolvedValue(600),
      incr: vi.fn().mockResolvedValue(1),
      expire: vi.fn().mockResolvedValue(1),
      del: vi.fn().mockResolvedValue(1),
    };

    const mockPostImageRepo = {
      find: vi.fn().mockResolvedValue([]),
      create: vi.fn((data: any) => data),
      save: vi.fn((data: any) => Promise.resolve(data)),
      delete: vi.fn().mockResolvedValue({ affected: 0 }),
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

  describe('Validation & Creation', () => {
    it('creates a post with valid mentions and dispatches notification', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);

      const content = 'Hey @sujeet, please check this update.';
      // '@sujeet' starts at 4, length 7
      const result = await service.createPost(mockAuthor.id, {
        content,
        category: PostCategory.GENERAL,
        mentions: [
          {
            userId: mockMentionedUser1.id,
            start: 4,
            length: 7,
          },
        ],
      });

      expect(result.mentions).toHaveLength(1);
      expect(result.mentions[0]).toEqual({
        userId: mockMentionedUser1.id,
        start: 4,
        length: 7,
        username: 'sujeet',
        displayName: 'Sujeet Kumar',
        avatarUrl: 'https://cdn.aaspaas.app/avatars/sujeet.png',
      });

      expect(mockPostMentionRepo.save).toHaveBeenCalled();
      expect(mockNotificationsService.createAndSend).toHaveBeenCalledWith(
        expect.objectContaining({
          recipientId: mockMentionedUser1.id,
          senderId: mockAuthor.id,
          type: NotificationType.USER_MENTIONED,
          category: NotificationCategory.SOCIAL,
          title: 'Author Neighbor mentioned you',
          body: 'Author Neighbor mentioned you in a post.',
          deepLink: '/feed/posts/post-new-1',
          deduplicationKey: 'mention:post-new-1:usr-sujeet-uuid',
        }),
      );
    });

    it('rejects mention if mentioned user ID does not exist', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      mockUserRepo.find.mockResolvedValue([]); // No users found

      const content = 'Hey @sujeet, check this!';
      await expect(
        service.createPost(mockAuthor.id, {
          content,
          mentions: [
            {
              userId: '00000000-0000-0000-0000-000000000099',
              start: 4,
              length: 7,
            },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects mention if token text does not match mentioned user username', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      // user is @sujeet, but token in text is @wrongname
      const content = 'Hey @wrongname, check this!';
      await expect(
        service.createPost(mockAuthor.id, {
          content,
          mentions: [
            {
              userId: mockMentionedUser1.id, // @sujeet
              start: 4,
              length: 10, // '@wrongname'
            },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects mention without @ prefix in token range', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      const content = 'Hey sujeet, check this!';
      await expect(
        service.createPost(mockAuthor.id, {
          content,
          mentions: [
            {
              userId: mockMentionedUser1.id,
              start: 4,
              length: 6, // 'sujeet' without @
            },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects overlapping mention ranges', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      const content = 'Hey @sujeet @suman!';
      await expect(
        service.createPost(mockAuthor.id, {
          content,
          mentions: [
            { userId: mockMentionedUser1.id, start: 4, length: 7 },
            { userId: mockMentionedUser2.id, start: 8, length: 6 }, // overlaps with range 4..11
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('permits self-mention in post but suppresses self-notification', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      const content = 'Notes for myself @author_user: reminder!';
      const result = await service.createPost(mockAuthor.id, {
        content,
        mentions: [
          {
            userId: mockAuthor.id,
            start: 17,
            length: 12, // '@author_user'
          },
        ],
      });

      expect(result.mentions).toHaveLength(1);
      expect(result.mentions[0].userId).toBe(mockAuthor.id);
      // Notification must NOT be dispatched to author themselves
      expect(mockNotificationsService.createAndSend).not.toHaveBeenCalled();
    });

    it('supports multiple mentions and notifies each user once', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      const content = 'Hello @sujeet and @suman!';
      const result = await service.createPost(mockAuthor.id, {
        content,
        mentions: [
          { userId: mockMentionedUser1.id, start: 6, length: 7 }, // @sujeet
          { userId: mockMentionedUser2.id, start: 18, length: 6 }, // @suman
        ],
      });

      expect(result.mentions).toHaveLength(2);
      expect(mockNotificationsService.createAndSend).toHaveBeenCalledTimes(2);
    });

    it('deduplicates notifications when same user is mentioned multiple times', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      const content = '@sujeet please check and @sujeet thank you!';
      const result = await service.createPost(mockAuthor.id, {
        content,
        mentions: [
          { userId: mockMentionedUser1.id, start: 0, length: 7 },
          { userId: mockMentionedUser1.id, start: 25, length: 7 },
        ],
      });

      expect(result.mentions).toHaveLength(2);
      // Only 1 notification dispatched to mockMentionedUser1
      expect(mockNotificationsService.createAndSend).toHaveBeenCalledTimes(1);
    });

    it('defaults to empty mentions array when no mentions are passed', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockAuthor);
      const result = await service.createPost(mockAuthor.id, {
        content: 'Post with no mentions at all.',
      });

      expect(result.mentions).toEqual([]);
      expect(mockNotificationsService.createAndSend).not.toHaveBeenCalled();
    });
  });

  describe('Post Retrieval & Updates', () => {
    it('getPostById returns structured mentions resolved with latest usernames', async () => {
      const mockPostEntity: Post = {
        id: 'post-100',
        authorId: mockAuthor.id,
        author: mockAuthor,
        content: 'Hello @sujeet_updated!',
        category: PostCategory.GENERAL,
        countryCode: 'IN',
        likeCount: 0,
        commentCount: 0,
        reactions: [],
        comments: [],
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      const mockQb = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        leftJoin: vi.fn().mockReturnThis(),
        addSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [mockPostEntity],
          raw: [{ currentUserLiked: false }],
        }),
      };
      mockPostRepo.createQueryBuilder.mockReturnValue(mockQb);

      // User changed username from sujeet -> sujeet_updated, but immutable userId is the same!
      mockPostMentionRepo.find.mockResolvedValue([
        {
          id: 'pm-1',
          postId: 'post-100',
          mentionedUserId: mockMentionedUser1.id,
          start: 6,
          length: 15,
          mentionedUser: {
            ...mockMentionedUser1,
            username: 'sujeet_updated',
          },
        },
      ]);

      const post = await service.getPostById('post-100', mockAuthor.id);
      expect(post.mentions).toHaveLength(1);
      expect(post.mentions[0].userId).toBe(mockMentionedUser1.id);
      expect(post.mentions[0].username).toBe('sujeet_updated');
    });

    it('updatePost updates post mentions and notifies newly mentioned users', async () => {
      const existingPost: Post = {
        id: 'post-200',
        authorId: mockAuthor.id,
        author: mockAuthor,
        content: 'Initial text without mentions',
        category: PostCategory.GENERAL,
        countryCode: 'IN',
        likeCount: 0,
        commentCount: 0,
        reactions: [],
        comments: [],
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockPostRepo.findOne.mockResolvedValue(existingPost);

      // Mock getPostById for after update
      const mockQb = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        leftJoin: vi.fn().mockReturnThis(),
        addSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [{ ...existingPost, content: 'Now mentioning @sujeet' }],
          raw: [{ currentUserLiked: false }],
        }),
      };
      mockPostRepo.createQueryBuilder.mockReturnValue(mockQb);
      mockPostMentionRepo.find.mockResolvedValue([
        {
          id: 'pm-200',
          postId: 'post-200',
          mentionedUserId: mockMentionedUser1.id,
          start: 15,
          length: 7,
          mentionedUser: mockMentionedUser1,
        },
      ]);

      const updated = await service.updatePost('post-200', mockAuthor.id, {
        content: 'Now mentioning @sujeet',
        mentions: [
          {
            userId: mockMentionedUser1.id,
            start: 15,
            length: 7,
          },
        ],
      });

      expect(mockPostMentionRepo.delete).toHaveBeenCalledWith({ postId: 'post-200' });
      expect(mockPostMentionRepo.save).toHaveBeenCalled();
      expect(mockNotificationsService.createAndSend).toHaveBeenCalledWith(
        expect.objectContaining({
          recipientId: mockMentionedUser1.id,
          type: NotificationType.USER_MENTIONED,
        }),
      );
      expect(updated.mentions).toHaveLength(1);
    });
  });
});

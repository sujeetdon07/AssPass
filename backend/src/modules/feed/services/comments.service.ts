import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Logger,
  Optional,
  Inject,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Comment } from '../entities/comment.entity.js';
import { Post } from '../entities/post.entity.js';
import { User } from '../../users/entities/user.entity.js';
import { CreateCommentDto } from '../dto/create-comment.dto.js';
import { RedisService } from '../../../database/redis.service.js';
import { NotificationsService } from '../../notifications/notifications.service.js';
import { NotificationType } from '../../notifications/enums/notification-type.enum.js';
import { NotificationCategory } from '../../notifications/enums/notification-category.enum.js';

export interface CommentResponse {
  id: string;
  postId: string;
  authorId: string;
  author: {
    username?: string | null;
    displayName: string | null;
    avatarUrl: string | null;
    locality: string | null;
    city: string | null;
  };
  content: string;
  createdAt: Date;
  updatedAt: Date;
  isOwnComment: boolean;
}

export interface PaginatedCommentsResponse {
  comments: CommentResponse[];
  nextCursor?: string;
  hasMore: boolean;
  totalCount: number;
}

@Injectable()
export class CommentsService {
  private readonly logger = new Logger(CommentsService.name);
  private readonly maxCommentsPerWindow = 30; // 30 comments per 10 minutes
  private readonly rateLimitWindowSeconds = 600;

  constructor(
    @InjectRepository(Comment)
    private readonly commentRepository: Repository<Comment>,
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly redisService: RedisService,
    private readonly dataSource: DataSource,
    @Optional()
    @Inject(NotificationsService)
    private readonly notificationsService?: NotificationsService,
  ) {}

  /**
   * List paginated comments for a post.
   */
  async getComments(
    postId: string,
    currentUserId?: string,
    limit: number = 20,
    cursor?: string,
  ): Promise<PaginatedCommentsResponse> {
    const post = await this.postRepository.findOne({
      where: { id: postId },
    });

    if (!post) {
      throw new NotFoundException('Post not found.');
    }

    const qb = this.commentRepository
      .createQueryBuilder('comment')
      .leftJoinAndSelect('comment.author', 'author')
      .where('comment.postId = :postId', { postId })
      .andWhere('comment.deletedAt IS NULL')
      .orderBy('comment.createdAt', 'ASC')
      .take(limit + 1);

    if (cursor) {
      try {
        const decoded = Buffer.from(cursor, 'base64').toString('utf8');
        const [cursorTimestamp, cursorId] = decoded.split(',');
        const cursorDate = new Date(cursorTimestamp);
        qb.andWhere(
          '(comment.createdAt > :cursorDate OR (comment.createdAt = :cursorDate AND comment.id > :cursorId))',
          { cursorDate, cursorId },
        );
      } catch {
        // Fallback if cursor format is corrupt
      }
    }

    const comments = await qb.getMany();
    const hasMore = comments.length > limit;
    const pageComments = hasMore ? comments.slice(0, limit) : comments;

    let nextCursor: string | undefined;
    if (hasMore && pageComments.length > 0) {
      const last = pageComments[pageComments.length - 1];
      const raw = `${last.createdAt.toISOString()},${last.id}`;
      nextCursor = Buffer.from(raw).toString('base64');
    }

    return {
      comments: pageComments.map((c) => ({
        id: c.id,
        postId: c.postId,
        authorId: c.authorId,
        author: {
          username: c.author?.username ?? null,
          displayName: c.author?.displayName ?? 'Neighbor',
          avatarUrl: c.author?.avatarUrl ?? null,
          locality: c.author?.locality ?? null,
          city: c.author?.city ?? null,
        },
        content: c.content,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        isOwnComment: currentUserId === c.authorId,
      })),
      nextCursor,
      hasMore,
      totalCount: post.commentCount,
    };
  }

  /**
   * Create a new comment on a post with abuse rate limiting and atomic counter update.
   */
  async createComment(
    postId: string,
    authorId: string,
    dto: CreateCommentDto,
  ): Promise<CommentResponse> {
    const post = await this.postRepository.findOne({
      where: { id: postId },
    });

    if (!post) {
      throw new NotFoundException('Post not found or has been removed.');
    }

    // Rate limiting: 30 comments per 10 minutes (atomic Lua INCR + EXPIRE)
    const rateKey = `rate:comment:${authorId}`;
    const count = typeof this.redisService.incrementWithExpire === 'function'
      ? await this.redisService.incrementWithExpire(rateKey, this.rateLimitWindowSeconds)
      : await this.redisService.incr(rateKey);

    if (count > this.maxCommentsPerWindow) {
      throw new HttpException(
        {
          code: 'RATE_LIMITED',
          message: 'You are commenting too quickly. Please wait a few minutes before trying again.',
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const author = await this.userRepository.findOne({
      where: { id: authorId },
    });

    return this.dataSource.transaction(async (manager) => {
      const comment = manager.create(Comment, {
        postId,
        authorId,
        content: dto.content,
      });

      const savedComment = await manager.save(comment);
      await manager.increment(Post, { id: postId }, 'commentCount', 1);

      // Dispatch notification to post author if commenter is not post author
      if (this.notificationsService && post.authorId && post.authorId !== authorId) {
        const commenterName = author?.displayName ?? 'A neighbor';
        this.notificationsService
          .createAndSend({
            recipientId: post.authorId,
            senderId: authorId,
            type: NotificationType.POST_COMMENTED,
            category: NotificationCategory.SOCIAL,
            title: 'New comment on your post',
            body: `${commenterName} commented on your post`,
            deepLink: `/feed/posts/${postId}`,
            data: { postId, commentId: savedComment.id },
            deduplicationKey: `comment:${savedComment.id}`,
          })
          .catch((err) => {
            this.logger.warn(`Failed to send comment notification: ${err?.message}`);
          });
      }

      return {
        id: savedComment.id,
        postId: savedComment.postId,
        authorId: savedComment.authorId,
        author: {
          username: author?.username ?? null,
          displayName: author?.displayName ?? 'Neighbor',
          avatarUrl: author?.avatarUrl ?? null,
          locality: author?.locality ?? null,
          city: author?.city ?? null,
        },
        content: savedComment.content,
        createdAt: savedComment.createdAt,
        updatedAt: savedComment.updatedAt,
        isOwnComment: true,
      };
    });
  }

  /**
   * Delete own comment with server-side authorization check.
   */
  async deleteComment(commentId: string, userId: string): Promise<void> {
    const comment = await this.commentRepository.findOne({
      where: { id: commentId },
    });

    if (!comment) {
      throw new NotFoundException('Comment not found.');
    }

    if (comment.authorId !== userId) {
      throw new ForbiddenException('You can only delete your own comments.');
    }

    await this.dataSource.transaction(async (manager) => {
      await manager.softDelete(Comment, { id: commentId });
      await manager.decrement(Post, { id: comment.postId }, 'commentCount', 1);

      // Clamp if negative
      const updatedPost = await manager.findOne(Post, { where: { id: comment.postId } });
      if (updatedPost && updatedPost.commentCount < 0) {
        await manager.update(Post, { id: comment.postId }, { commentCount: 0 });
      }
    });
  }
}

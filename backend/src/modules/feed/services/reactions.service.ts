import {
  Injectable,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Post } from '../entities/post.entity.js';
import { PostReaction, ReactionType } from '../entities/post-reaction.entity.js';

export interface ReactionResult {
  liked: boolean;
  likeCount: number;
}

@Injectable()
export class ReactionsService {
  private readonly logger = new Logger(ReactionsService.name);

  constructor(
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(PostReaction)
    private readonly reactionRepository: Repository<PostReaction>,
    private readonly dataSource: DataSource,
  ) {}

  /**
   * Idempotently like a post.
   * If already liked, returns existing state without double-counting.
   */
  async likePost(postId: string, userId: string): Promise<ReactionResult> {
    const post = await this.postRepository.findOne({
      where: { id: postId },
    });

    if (!post) {
      throw new NotFoundException('Post not found.');
    }

    const existing = await this.reactionRepository.findOne({
      where: { postId, userId, reactionType: ReactionType.LIKE },
    });

    if (existing) {
      return { liked: true, likeCount: post.likeCount };
    }

    return this.dataSource.transaction(async (manager) => {
      const reaction = manager.create(PostReaction, {
        postId,
        userId,
        reactionType: ReactionType.LIKE,
      });

      try {
        await manager.save(reaction);
      } catch (err: unknown) {
        // Handle potential race condition on unique constraint
        this.logger.warn(`Concurrent like detected for user ${userId} on post ${postId}: ${String(err)}`);
        const reloaded = await manager.findOne(Post, { where: { id: postId } });
        return { liked: true, likeCount: reloaded?.likeCount ?? post.likeCount };
      }

      await manager.increment(Post, { id: postId }, 'likeCount', 1);
      const updatedPost = await manager.findOne(Post, { where: { id: postId } });

      return {
        liked: true,
        likeCount: updatedPost?.likeCount ?? post.likeCount + 1,
      };
    });
  }

  /**
   * Idempotently unlike a post.
   */
  async unlikePost(postId: string, userId: string): Promise<ReactionResult> {
    const post = await this.postRepository.findOne({
      where: { id: postId },
    });

    if (!post) {
      throw new NotFoundException('Post not found.');
    }

    const existing = await this.reactionRepository.findOne({
      where: { postId, userId, reactionType: ReactionType.LIKE },
    });

    if (!existing) {
      return { liked: false, likeCount: Math.max(0, post.likeCount) };
    }

    return this.dataSource.transaction(async (manager) => {
      await manager.delete(PostReaction, { id: existing.id });
      await manager.decrement(Post, { id: postId }, 'likeCount', 1);

      const updatedPost = await manager.findOne(Post, { where: { id: postId } });
      const currentCount = Math.max(0, updatedPost?.likeCount ?? post.likeCount - 1);

      // Clamp if negative
      if (updatedPost && updatedPost.likeCount < 0) {
        await manager.update(Post, { id: postId }, { likeCount: 0 });
      }

      return {
        liked: false,
        likeCount: currentCount,
      };
    });
  }
}

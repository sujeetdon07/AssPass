import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Post, PostCategory } from '../entities/post.entity.js';
import { ReactionType } from '../entities/post-reaction.entity.js';
import { User } from '../../users/entities/user.entity.js';
import { CreatePostDto } from '../dto/create-post.dto.js';
import { UpdatePostDto } from '../dto/update-post.dto.js';
import { GetFeedQueryDto, FeedScope } from '../dto/get-feed-query.dto.js';
import { RedisService } from '../../../database/redis.service.js';
import { getLocalityCentroid } from '../../localities/utils/locality-centroid.util.js';

export interface AuthorSummary {
  id: string;
  displayName: string | null;
  avatarUrl: string | null;
  locality: string | null;
  city: string | null;
}

export interface PostResponse {
  id: string;
  authorId: string;
  author: AuthorSummary;
  content: string;
  category: PostCategory;
  countryCode: string;
  state: string | null;
  district: string | null;
  city: string | null;
  locality: string | null;
  neighborhood: string | null;
  likeCount: number;
  commentCount: number;
  currentUserLiked: boolean;
  isOwnPost: boolean;
  communityId?: string | null;
  community?: {
    id: string;
    name: string;
    slug: string;
  } | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface PaginatedFeedResponse {
  posts: PostResponse[];
  nextCursor?: string;
  hasMore: boolean;
  scope: string;
}

@Injectable()
export class FeedService {
  private readonly logger = new Logger(FeedService.name);
  private readonly maxPostsPerWindow = 10; // 10 posts per 10 minutes
  private readonly rateLimitWindowSeconds = 600;

  constructor(
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly redisService: RedisService,
  ) {}

  /**
   * List paginated community feed posts with cursor pagination and locality scoping.
   */
  async getFeed(
    currentUserId: string,
    query: GetFeedQueryDto,
  ): Promise<PaginatedFeedResponse> {
    const limit = query.limit ?? 20;
    const currentUser = await this.userRepository.findOne({
      where: { id: currentUserId },
    });

    const qb = this.postRepository
      .createQueryBuilder('post')
      .leftJoinAndSelect('post.author', 'author')
      .leftJoin('communities', 'comm', 'comm.id = post.communityId')
      .leftJoin(
        'post_reactions',
        'userReaction',
        'userReaction.postId = post.id AND userReaction.userId = :currentUserId AND userReaction.reactionType = :like',
        { currentUserId, like: ReactionType.LIKE },
      )
      .addSelect('CASE WHEN userReaction.id IS NOT NULL THEN true ELSE false END', 'currentUserLiked')
      .addSelect('comm.id', 'comm_id')
      .addSelect('comm.name', 'comm_name')
      .addSelect('comm.slug', 'comm_slug')
      .where('post.deletedAt IS NULL')
      .andWhere(
        '(post.communityId IS NULL OR (comm.visibility = :publicVisibility AND comm.status = :activeStatus))',
        { publicVisibility: 'public', activeStatus: 'active' },
      );

    // 1. Locality scoping
    if (query.scope === FeedScope.LOCAL && currentUser?.city) {
      qb.andWhere(
        '(post.city = :city OR post.locality = :locality)',
        {
          city: currentUser.city,
          locality: currentUser.locality ?? '',
        },
      );
    }

    // 2. Category filtering
    if (query.category) {
      qb.andWhere('post.category = :category', { category: query.category });
    }

    // 3. Cursor pagination (newest first: createdAt DESC, id DESC)
    if (query.cursor) {
      try {
        const decoded = Buffer.from(query.cursor, 'base64').toString('utf8');
        const [cursorTimestamp, cursorId] = decoded.split(',');
        const cursorDate = new Date(cursorTimestamp);
        qb.andWhere(
          '(post.createdAt < :cursorDate OR (post.createdAt = :cursorDate AND post.id < :cursorId))',
          { cursorDate, cursorId },
        );
      } catch {
        this.logger.warn(`Malformed cursor received: ${query.cursor}`);
      }
    }

    qb.orderBy('post.createdAt', 'DESC')
      .addOrderBy('post.id', 'DESC')
      .take(limit + 1);

    const { entities, raw } = await qb.getRawAndEntities();
    const hasMore = entities.length > limit;
    const pageEntities = hasMore ? entities.slice(0, limit) : entities;
    const pageRaw = hasMore ? raw.slice(0, limit) : raw;

    let nextCursor: string | undefined;
    if (hasMore && pageEntities.length > 0) {
      const last = pageEntities[pageEntities.length - 1];
      const rawCursor = `${last.createdAt.toISOString()},${last.id}`;
      nextCursor = Buffer.from(rawCursor).toString('base64');
    }

    const posts: PostResponse[] = pageEntities.map((post, index) => {
      const rawLiked = pageRaw[index]?.currentUserLiked;
      const currentUserLiked = rawLiked === true || rawLiked === 'true' || rawLiked === 1;
      const commId = pageRaw[index]?.comm_id;
      const commName = pageRaw[index]?.comm_name;
      const commSlug = pageRaw[index]?.comm_slug;

      return {
        id: post.id,
        authorId: post.authorId,
        author: {
          id: post.author?.id ?? post.authorId,
          displayName: post.author?.displayName ?? 'Neighbor',
          avatarUrl: post.author?.avatarUrl ?? null,
          locality: post.author?.locality ?? post.locality ?? null,
          city: post.author?.city ?? post.city ?? null,
        },
        content: post.content,
        category: post.category,
        countryCode: post.countryCode,
        state: post.state ?? null,
        district: post.district ?? null,
        city: post.city ?? null,
        locality: post.locality ?? null,
        neighborhood: post.neighborhood ?? null,
        likeCount: post.likeCount,
        commentCount: post.commentCount,
        currentUserLiked,
        isOwnPost: post.authorId === currentUserId,
        communityId: post.communityId ?? commId ?? null,
        community: commId ? { id: commId, name: commName, slug: commSlug } : null,
        createdAt: post.createdAt,
        updatedAt: post.updatedAt,
      };
    });

    return {
      posts,
      nextCursor,
      hasMore,
      scope: query.scope ?? FeedScope.LOCAL,
    };
  }

  /**
   * Retrieve single post details by ID.
   */
  async getPostById(postId: string, currentUserId?: string): Promise<PostResponse> {
    const qb = this.postRepository
      .createQueryBuilder('post')
      .leftJoinAndSelect('post.author', 'author')
      .leftJoin('communities', 'comm', 'comm.id = post.communityId')
      .leftJoin(
        'community_members',
        'myMembership',
        'myMembership.communityId = post.communityId AND myMembership.userId = :currentUserId AND myMembership.status = :activeStatus',
        { currentUserId: currentUserId ?? '00000000-0000-0000-0000-000000000000', activeStatus: 'active' },
      )
      .leftJoin(
        'post_reactions',
        'userReaction',
        'userReaction.postId = post.id AND userReaction.userId = :currentUserId AND userReaction.reactionType = :like',
        { currentUserId: currentUserId ?? '00000000-0000-0000-0000-000000000000', like: ReactionType.LIKE },
      )
      .addSelect('CASE WHEN userReaction.id IS NOT NULL THEN true ELSE false END', 'currentUserLiked')
      .addSelect('comm.id', 'comm_id')
      .addSelect('comm.name', 'comm_name')
      .addSelect('comm.slug', 'comm_slug')
      .addSelect('comm.visibility', 'comm_visibility')
      .addSelect('CASE WHEN myMembership.id IS NOT NULL THEN true ELSE false END', 'isCommunityMember')
      .where('post.id = :postId', { postId })
      .andWhere('post.deletedAt IS NULL');

    const { entities, raw } = await qb.getRawAndEntities();

    if (entities.length === 0) {
      throw new NotFoundException('Post not found or has been removed.');
    }

    const post = entities[0];
    const rawLiked = raw[0]?.currentUserLiked;
    const currentUserLiked = rawLiked === true || rawLiked === 'true' || rawLiked === 1;
    const commId = raw[0]?.comm_id;
    const commName = raw[0]?.comm_name;
    const commSlug = raw[0]?.comm_slug;
    const commVisibility = raw[0]?.comm_visibility;
    const isCommunityMember =
      raw[0]?.isCommunityMember === true ||
      raw[0]?.isCommunityMember === 'true' ||
      raw[0]?.isCommunityMember === 1;

    if (
      commId &&
      commVisibility === 'private' &&
      !isCommunityMember &&
      post.authorId !== currentUserId
    ) {
      throw new ForbiddenException(
        'Membership is required to view posts in this private community.',
      );
    }

    return {
      id: post.id,
      authorId: post.authorId,
      author: {
        id: post.author?.id ?? post.authorId,
        displayName: post.author?.displayName ?? 'Neighbor',
        avatarUrl: post.author?.avatarUrl ?? null,
        locality: post.author?.locality ?? post.locality ?? null,
        city: post.author?.city ?? post.city ?? null,
      },
      content: post.content,
      category: post.category,
      countryCode: post.countryCode,
      state: post.state ?? null,
      district: post.district ?? null,
      city: post.city ?? null,
      locality: post.locality ?? null,
      neighborhood: post.neighborhood ?? null,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      currentUserLiked,
      isOwnPost: post.authorId === currentUserId,
      communityId: post.communityId ?? commId ?? null,
      community: commId ? { id: commId, name: commName, slug: commSlug } : null,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
    };
  }

  /**
   * Create a new post. Automatically inherits locality context from the author.
   */
  async createPost(authorId: string, dto: CreatePostDto): Promise<PostResponse> {
    const author = await this.userRepository.findOne({
      where: { id: authorId },
    });

    if (!author) {
      throw new NotFoundException('User profile not found.');
    }

    // Rate limiting: 10 posts per 10 minutes
    const rateKey = `rate:post:${authorId}`;
    const currentRate = await this.redisService.get(rateKey);
    const count = currentRate ? parseInt(currentRate, 10) : 0;

    if (count >= this.maxPostsPerWindow) {
      throw new HttpException(
        {
          code: 'RATE_LIMITED',
          message: 'You are posting too frequently. Please wait a few minutes before sharing again.',
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const post = this.postRepository.create({
      authorId,
      content: dto.content,
      category: dto.category ?? PostCategory.GENERAL,
      countryCode: author.countryCode ?? 'IN',
      state: author.state,
      district: author.district,
      city: author.city,
      locality: author.locality,
      neighborhood: author.neighborhood,
      likeCount: 0,
      commentCount: 0,
    });

    const saved = await this.postRepository.save(post);

    // Assign safe public locality centroid location in PostGIS
    try {
      const coords = getLocalityCentroid(author.locality, author.city);
      await this.postRepository.query(
        'UPDATE "posts" SET "location" = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography WHERE id = $3',
        [coords.longitude, coords.latitude, saved.id],
      );
    } catch (err) {
      this.logger.warn(`Could not set spatial location on post ${saved.id}: ${err}`);
    }

    // Update rate limiter
    if (count === 0) {
      await this.redisService.set(rateKey, '1', this.rateLimitWindowSeconds);
    } else {
      const ttl = await this.redisService.ttl(rateKey);
      await this.redisService.set(
        rateKey,
        (count + 1).toString(),
        ttl > 0 ? ttl : this.rateLimitWindowSeconds,
      );
    }

    return {
      id: saved.id,
      authorId: saved.authorId,
      author: {
        id: author.id,
        displayName: author.displayName ?? 'Neighbor',
        avatarUrl: author.avatarUrl ?? null,
        locality: author.locality ?? null,
        city: author.city ?? null,
      },
      content: saved.content,
      category: saved.category,
      countryCode: saved.countryCode,
      state: saved.state ?? null,
      district: saved.district ?? null,
      city: saved.city ?? null,
      locality: saved.locality ?? null,
      neighborhood: saved.neighborhood ?? null,
      likeCount: 0,
      commentCount: 0,
      currentUserLiked: false,
      isOwnPost: true,
      createdAt: saved.createdAt,
      updatedAt: saved.updatedAt,
    };
  }

  /**
   * Edit own post content with strict server-side ownership authorization.
   */
  async updatePost(
    postId: string,
    userId: string,
    dto: UpdatePostDto,
  ): Promise<PostResponse> {
    const post = await this.postRepository.findOne({
      where: { id: postId },
      relations: ['author'],
    });

    if (!post) {
      throw new NotFoundException('Post not found or has been removed.');
    }

    if (post.authorId !== userId) {
      throw new ForbiddenException('You can only edit your own posts.');
    }

    post.content = dto.content;
    const updated = await this.postRepository.save(post);

    return this.getPostById(updated.id, userId);
  }

  /**
   * Soft delete own post with ownership authorization.
   */
  async deletePost(postId: string, userId: string): Promise<void> {
    const post = await this.postRepository.findOne({
      where: { id: postId },
    });

    if (!post) {
      throw new NotFoundException('Post not found.');
    }

    if (post.authorId !== userId) {
      throw new ForbiddenException('You can only delete your own posts.');
    }

    await this.postRepository.softDelete({ id: postId });
  }
}

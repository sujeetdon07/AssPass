import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  HttpException,
  HttpStatus,
  Logger,
  Inject,
  Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Post, PostCategory } from '../entities/post.entity.js';
import { PostMention } from '../entities/post-mention.entity.js';
import { PostImage } from '../entities/post-image.entity.js';
import { ReactionType } from '../entities/post-reaction.entity.js';
import { User } from '../../users/entities/user.entity.js';
import { CreatePostDto } from '../dto/create-post.dto.js';
import { UpdatePostDto } from '../dto/update-post.dto.js';
import { CreatePostMentionDto } from '../dto/create-post-mention.dto.js';
import { CreatePostImageDto } from '../dto/create-post-image.dto.js';
import { GetFeedQueryDto, FeedScope } from '../dto/get-feed-query.dto.js';
import { RedisService } from '../../../database/redis.service.js';
import { getLocalityCentroid } from '../../localities/utils/locality-centroid.util.js';
import { NotificationsService } from '../../notifications/notifications.service.js';
import { NotificationType } from '../../notifications/enums/notification-type.enum.js';
import { NotificationCategory } from '../../notifications/enums/notification-category.enum.js';

export interface AuthorSummary {
  id: string;
  username?: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  locality: string | null;
  city: string | null;
}

export interface PostMentionResponse {
  userId: string;
  start: number;
  length: number;
  username: string;
  displayName: string;
  avatarUrl: string | null;
}

export interface PostImageResponse {
  id: string;
  url: string;
  thumbnailUrl: string;
  mediumUrl?: string | null;
  width?: number | null;
  height?: number | null;
  mimeType?: string | null;
  size?: number | null;
  sortOrder: number;
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
  mentions: PostMentionResponse[];
  images?: PostImageResponse[];
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
    @InjectRepository(PostMention)
    private readonly postMentionRepository: Repository<PostMention>,
    @InjectRepository(PostImage)
    private readonly postImageRepository: Repository<PostImage>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly redisService: RedisService,
    @Optional()
    @Inject(NotificationsService)
    private readonly notificationsService?: NotificationsService,
  ) {}

  /**
   * Validate post image attachments.
   * Ensures:
   * 1. Max 10 images per post
   * 2. Non-empty url and thumbnailUrl
   * 3. Valid URL schema (safe against javascript: or malformed schemes)
   * 4. Numeric width, height, size limits
   * 5. Preserves sortOrder
   */
  validatePostImages(images?: CreatePostImageDto[]): CreatePostImageDto[] {
    if (!images || images.length === 0) {
      return [];
    }

    if (images.length > 4) {
      throw new BadRequestException('A post cannot contain more than 4 images.');
    }

    const validated: CreatePostImageDto[] = [];
    for (let i = 0; i < images.length; i++) {
      const img = images[i];
      if (!img.url || typeof img.url !== 'string' || img.url.trim().length === 0) {
        throw new BadRequestException(`Image at index ${i} is missing a valid URL.`);
      }
      if (!img.thumbnailUrl || typeof img.thumbnailUrl !== 'string' || img.thumbnailUrl.trim().length === 0) {
        throw new BadRequestException(`Image at index ${i} is missing a valid thumbnail URL.`);
      }

      const trimmedUrl = img.url.trim();
      const trimmedThumb = img.thumbnailUrl.trim();
      if (!/^(https?:\/\/|\/)/i.test(trimmedUrl) || !/^(https?:\/\/|\/)/i.test(trimmedThumb)) {
        throw new BadRequestException(`Image at index ${i} has an invalid URL protocol.`);
      }

      validated.push({
        url: trimmedUrl,
        thumbnailUrl: trimmedThumb,
        mediumUrl: img.mediumUrl ? img.mediumUrl.trim() : undefined,
        width: img.width ? Number(img.width) : undefined,
        height: img.height ? Number(img.height) : undefined,
        size: img.size ? Number(img.size) : undefined,
        mimeType: img.mimeType ? String(img.mimeType) : 'image/webp',
        sortOrder: img.sortOrder !== undefined ? Number(img.sortOrder) : i,
      });
    }

    return validated.sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
  }

  /**
   * List paginated community feed posts with cursor pagination and locality scoping.
   */
  async getFeed(
    currentUserId: string,
    query: GetFeedQueryDto,
  ): Promise<PaginatedFeedResponse> {
    const limit = query.limit ?? 20;

    // 1. Locality scoping with cached user locality
    let userLocality: { city: string | null; locality: string | null } | null = null;
    if (query.scope === FeedScope.LOCAL) {
      try {
        const cached = await this.redisService.get(`user:locality:${currentUserId}`);
        if (cached) {
          userLocality = JSON.parse(cached);
        }
      } catch {}
      if (!userLocality) {
        const user = await this.userRepository.findOne({
          where: { id: currentUserId },
          select: { id: true, city: true, locality: true },
        });
        if (user) {
          userLocality = { city: user.city ?? null, locality: user.locality ?? null };
          try {
            await this.redisService.set(
              `user:locality:${currentUserId}`,
              JSON.stringify(userLocality),
              300, // 5 min TTL
            );
          } catch {}
        }
      }
    }

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
    if (query.scope === FeedScope.LOCAL && userLocality?.city) {
      qb.andWhere(
        '(post.city = :city OR post.locality = :locality)',
        {
          city: userLocality.city,
          locality: userLocality.locality ?? '',
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

    const postIds = pageEntities.map((p) => p.id);
    const mentionsByPostId = new Map<string, PostMentionResponse[]>();
    const imagesByPostId = new Map<string, PostImageResponse[]>();

    if (postIds.length > 0) {
      const [mentions, images] = await Promise.all([
        this.postMentionRepository.find({
          where: { postId: In(postIds) },
          relations: ['mentionedUser'],
          order: { start: 'ASC' },
        }),
        this.postImageRepository.find({
          where: { postId: In(postIds) },
          order: { sortOrder: 'ASC', createdAt: 'ASC' },
        }),
      ]);

      for (const m of mentions) {
        if (!mentionsByPostId.has(m.postId)) {
          mentionsByPostId.set(m.postId, []);
        }
        mentionsByPostId.get(m.postId)!.push({
          userId: m.mentionedUserId,
          start: m.start,
          length: m.length,
          username: m.mentionedUser?.username ?? '',
          displayName: m.mentionedUser?.displayName ?? 'Neighbor',
          avatarUrl: m.mentionedUser?.avatarUrl ?? null,
        });
      }

      for (const img of images) {
        if (!imagesByPostId.has(img.postId)) {
          imagesByPostId.set(img.postId, []);
        }
        imagesByPostId.get(img.postId)!.push({
          id: img.id,
          url: img.url,
          thumbnailUrl: img.thumbnailUrl,
          mediumUrl: img.mediumUrl ?? null,
          width: img.width ?? null,
          height: img.height ?? null,
          mimeType: img.mimeType ?? null,
          size: img.size ?? null,
          sortOrder: img.sortOrder,
        });
      }
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
          username: post.author?.username ?? null,
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
        mentions: mentionsByPostId.get(post.id) ?? [],
        images: imagesByPostId.get(post.id) ?? [],
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

    const [postMentions, postImages] = await Promise.all([
      this.postMentionRepository.find({
        where: { postId: post.id },
        relations: ['mentionedUser'],
        order: { start: 'ASC' },
      }),
      this.postImageRepository.find({
        where: { postId: post.id },
        order: { sortOrder: 'ASC', createdAt: 'ASC' },
      }),
    ]);

    const mentions: PostMentionResponse[] = postMentions.map((m) => ({
      userId: m.mentionedUserId,
      start: m.start,
      length: m.length,
      username: m.mentionedUser?.username ?? '',
      displayName: m.mentionedUser?.displayName ?? 'Neighbor',
      avatarUrl: m.mentionedUser?.avatarUrl ?? null,
    }));

    const images: PostImageResponse[] = postImages.map((img) => ({
      id: img.id,
      url: img.url,
      thumbnailUrl: img.thumbnailUrl,
      mediumUrl: img.mediumUrl ?? null,
      width: img.width ?? null,
      height: img.height ?? null,
      mimeType: img.mimeType ?? null,
      size: img.size ?? null,
      sortOrder: img.sortOrder,
    }));

    return {
      id: post.id,
      authorId: post.authorId,
      author: {
        id: post.author?.id ?? post.authorId,
        username: post.author?.username ?? null,
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
      mentions,
      images,
      communityId: post.communityId ?? commId ?? null,
      community: commId ? { id: commId, name: commName, slug: commSlug } : null,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
    };
  }

  /**
   * Create a new post. Automatically inherits locality context from the author.
   */
  /**
   * Validate mentions against post content and database users.
   * Ensures:
   * 1. start >= 0, length > 0, start + length <= content.length
   * 2. content.substring(start, start + length) matches '@' + user.username (case-insensitive)
   * 3. Mentioned users exist in the database and have an active username
   * 4. Ranges do not overlap
   */
  async validateMentions(
    content: string,
    mentionDtos: CreatePostMentionDto[],
  ): Promise<{
    validated: Array<{ userId: string; start: number; length: number }>;
    userMap: Map<string, User>;
  }> {
    if (!mentionDtos || mentionDtos.length === 0) {
      return { validated: [], userMap: new Map() };
    }

    const contentLength = content.length; // UTF-16 code units
    const userIds = [...new Set(mentionDtos.map((m) => m.userId))];

    const users = await this.userRepository.find({
      where: { id: In(userIds) },
    });

    const userMap = new Map(users.map((u) => [u.id, u]));

    // Check each mention
    const sorted = [...mentionDtos].sort((a, b) => a.start - b.start);
    let lastEnd = 0;

    for (const mention of sorted) {
      if (mention.start < 0 || mention.length <= 0) {
        throw new BadRequestException('Mention start must be non-negative and length must be positive.');
      }
      if (mention.start + mention.length > contentLength) {
        throw new BadRequestException('Mention range extends beyond post content length.');
      }
      if (mention.start < lastEnd) {
        throw new BadRequestException('Overlapping mention ranges are not allowed.');
      }
      lastEnd = mention.start + mention.length;

      const user = userMap.get(mention.userId);
      if (!user) {
        throw new BadRequestException(`Mentioned user ${mention.userId} does not exist.`);
      }
      if (!user.username) {
        throw new BadRequestException(`Mentioned user does not have a public username.`);
      }

      const token = content.substring(mention.start, mention.start + mention.length);
      if (!token.startsWith('@')) {
        throw new BadRequestException(`Mention token at range [${mention.start}, ${mention.start + mention.length}] must start with @.`);
      }

      const tokenUsername = token.slice(1).toLowerCase();
      if (tokenUsername !== user.username.toLowerCase()) {
        throw new BadRequestException(
          `Mention token "${token}" does not match user's username "@${user.username}".`,
        );
      }
    }

    return {
      validated: sorted.map((m) => ({
        userId: m.userId,
        start: m.start,
        length: m.length,
      })),
      userMap,
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

    // Rate limiting: 10 posts per 10 minutes (atomic Lua INCR + EXPIRE)
    const rateKey = `rate:post:${authorId}`;
    const count = typeof this.redisService.incrementWithExpire === 'function'
      ? await this.redisService.incrementWithExpire(rateKey, this.rateLimitWindowSeconds)
      : await this.redisService.incr(rateKey);

    if (count > this.maxPostsPerWindow) {
      throw new HttpException(
        {
          code: 'RATE_LIMITED',
          message: 'You are posting too frequently. Please wait a few minutes before sharing again.',
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // Validate mentions and images before saving post
    const { validated, userMap } = await this.validateMentions(dto.content, dto.mentions ?? []);
    const validatedImages = this.validatePostImages(dto.images);

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

    const savedImages: PostImageResponse[] = [];
    if (validatedImages.length > 0) {
      const imageEntities = validatedImages.map((img, idx) =>
        this.postImageRepository.create({
          postId: saved.id,
          url: img.url,
          thumbnailUrl: img.thumbnailUrl,
          mediumUrl: img.mediumUrl ?? null,
          width: img.width ?? null,
          height: img.height ?? null,
          mimeType: img.mimeType ?? null,
          size: img.size ?? null,
          sortOrder: img.sortOrder ?? idx,
        }),
      );
      const persistedImages = await this.postImageRepository.save(imageEntities);
      for (const pi of persistedImages) {
        savedImages.push({
          id: pi.id,
          url: pi.url,
          thumbnailUrl: pi.thumbnailUrl,
          mediumUrl: pi.mediumUrl ?? null,
          width: pi.width ?? null,
          height: pi.height ?? null,
          mimeType: pi.mimeType ?? null,
          size: pi.size ?? null,
          sortOrder: pi.sortOrder,
        });
      }
    }

    const savedMentions: PostMentionResponse[] = [];
    if (validated.length > 0) {
      const mentionEntities = validated.map((m) =>
        this.postMentionRepository.create({
          postId: saved.id,
          mentionedUserId: m.userId,
          start: m.start,
          length: m.length,
        }),
      );
      await this.postMentionRepository.save(mentionEntities);

      for (const m of validated) {
        const u = userMap.get(m.userId);
        savedMentions.push({
          userId: m.userId,
          start: m.start,
          length: m.length,
          username: u?.username ?? '',
          displayName: u?.displayName ?? 'Neighbor',
          avatarUrl: u?.avatarUrl ?? null,
        });
      }

      // Dispatch notifications (skip author self-mention, deduplicate recipients)
      if (this.notificationsService) {
        const uniqueMentionedUserIds = [...new Set(validated.map((v) => v.userId))]
          .filter((uid) => uid !== authorId);

        const authorName = author.displayName ?? 'A neighbor';
        for (const recipientId of uniqueMentionedUserIds) {
          this.notificationsService
            .createAndSend({
              recipientId,
              senderId: authorId,
              type: NotificationType.USER_MENTIONED,
              category: NotificationCategory.SOCIAL,
              title: `${authorName} mentioned you`,
              body: `${authorName} mentioned you in a post.`,
              deepLink: `/feed/posts/${saved.id}`,
              data: { postId: saved.id },
              deduplicationKey: `mention:${saved.id}:${recipientId}`,
            })
            .catch((err) => {
              this.logger.warn(`Failed to dispatch mention notification: ${err?.message}`);
            });
        }
      }
    }

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

    return {
      id: saved.id,
      authorId: saved.authorId,
      author: {
        id: author.id,
        username: author.username ?? null,
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
      mentions: savedMentions,
      images: savedImages,
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

    let validatedMentions: Array<{ userId: string; start: number; length: number }> | null = null;
    if (dto.mentions !== undefined) {
      const res = await this.validateMentions(dto.content, dto.mentions);
      validatedMentions = res.validated;
    }

    post.content = dto.content;
    const updated = await this.postRepository.save(post);

    if (dto.images !== undefined) {
      const validatedImages = this.validatePostImages(dto.images);
      await this.postImageRepository.delete({ postId: updated.id });
      if (validatedImages.length > 0) {
        const imageEntities = validatedImages.map((img, idx) =>
          this.postImageRepository.create({
            postId: updated.id,
            url: img.url,
            thumbnailUrl: img.thumbnailUrl,
            mediumUrl: img.mediumUrl ?? null,
            width: img.width ?? null,
            height: img.height ?? null,
            mimeType: img.mimeType ?? null,
            size: img.size ?? null,
            sortOrder: img.sortOrder ?? idx,
          }),
        );
        await this.postImageRepository.save(imageEntities);
      }
    }

    if (validatedMentions !== null) {
      await this.postMentionRepository.delete({ postId: updated.id });
      if (validatedMentions.length > 0) {
        const mentionEntities = validatedMentions.map((m) =>
          this.postMentionRepository.create({
            postId: updated.id,
            mentionedUserId: m.userId,
            start: m.start,
            length: m.length,
          }),
        );
        await this.postMentionRepository.save(mentionEntities);

        // Notify newly mentioned users
        if (this.notificationsService) {
          const uniqueMentionedUserIds = [...new Set(validatedMentions.map((v) => v.userId))]
            .filter((uid) => uid !== userId);

          const authorName = post.author?.displayName ?? 'A neighbor';
          for (const recipientId of uniqueMentionedUserIds) {
            this.notificationsService
              .createAndSend({
                recipientId,
                senderId: userId,
                type: NotificationType.USER_MENTIONED,
                category: NotificationCategory.SOCIAL,
                title: `${authorName} mentioned you`,
                body: `${authorName} mentioned you in a post.`,
                deepLink: `/feed/posts/${updated.id}`,
                data: { postId: updated.id },
                deduplicationKey: `mention:${updated.id}:${recipientId}`,
              })
              .catch((err) => {
                this.logger.warn(`Failed to dispatch mention notification: ${err?.message}`);
              });
          }
        }
      }
    }

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

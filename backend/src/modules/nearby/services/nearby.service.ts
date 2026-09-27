import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Post, PostCategory } from '../../feed/entities/post.entity.js';
import { ReactionType } from '../../feed/entities/post-reaction.entity.js';
import { RedisService } from '../../../database/redis.service.js';
import { GetNearbyPostsDto, DEFAULT_RADIUS_KM } from '../dto/get-nearby-posts.dto.js';
import {
  NearbyPostResponse,
  PaginatedNearbyResponse,
  formatPrivacySafeDistance,
} from '../dto/nearby-post-response.dto.js';

interface RawNearbyRow {
  id: string;
  authorId: string;
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
  createdAt: Date | string;
  updatedAt: Date | string;
  author_id: string;
  author_displayName: string | null;
  author_avatarUrl: string | null;
  author_locality: string | null;
  author_city: string | null;
  currentUserLiked: boolean | string | number;
  distance_meters: number | string;
  comm_id?: string | null;
  comm_name?: string | null;
  comm_slug?: string | null;
}

@Injectable()
export class NearbyService {
  private readonly logger = new Logger(NearbyService.name);
  private readonly maxQueriesPerMinute = 60;
  private readonly rateLimitWindowSeconds = 60;

  constructor(
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    private readonly redisService: RedisService,
  ) {}

  /**
   * Discovers nearby posts within a specified radius (km) using PostGIS spatial indexing.
   * Returns deterministic cursor-paginated results with privacy-safe distance formatting.
   */
  async getNearbyPosts(
    currentUserId: string,
    dto: GetNearbyPostsDto,
  ): Promise<PaginatedNearbyResponse> {
    const { latitude, longitude, category, cursor } = dto;
    const radiusKm = dto.radius ?? DEFAULT_RADIUS_KM;
    const radiusMeters = radiusKm * 1000;
    const limit = dto.limit ?? 20;

    // Rate limiting: 60 nearby searches per minute per user (atomic Lua INCR + EXPIRE)
    const rateKey = `rate:nearby:${currentUserId}`;
    try {
      const count = typeof this.redisService.incrementWithExpire === 'function'
        ? await this.redisService.incrementWithExpire(rateKey, this.rateLimitWindowSeconds)
        : await this.redisService.incr(rateKey);
      if (count > this.maxQueriesPerMinute) {
        throw new HttpException(
          {
            code: 'RATE_LIMITED',
            message: 'Too many nearby searches. Please wait a moment before searching again.',
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    } catch (err) {
      if (err instanceof HttpException) throw err;
      this.logger.warn(`Redis rate limit check failed: ${err}`);
    }

    // Build PostGIS spatial query using parameter binding
    const qb = this.postRepository
      .createQueryBuilder('post')
      .leftJoin('users', 'author', 'author.id = post.authorId')
      .leftJoin('communities', 'comm', 'comm.id = post.communityId')
      .leftJoin(
        'post_reactions',
        'userReaction',
        'userReaction.postId = post.id AND userReaction.userId = :currentUserId AND userReaction.reactionType = :like',
        { currentUserId, like: ReactionType.LIKE },
      )
      .select([
        'post.id AS id',
        'post.authorId AS "authorId"',
        'post.content AS content',
        'post.category AS category',
        'post.countryCode AS "countryCode"',
        'post.state AS state',
        'post.district AS district',
        'post.city AS city',
        'post.locality AS locality',
        'post.neighborhood AS neighborhood',
        'post.likeCount AS "likeCount"',
        'post.commentCount AS "commentCount"',
        'post.createdAt AS "createdAt"',
        'post.updatedAt AS "updatedAt"',
        'author.id AS author_id',
        'author.displayName AS "author_displayName"',
        'author.avatarUrl AS "author_avatarUrl"',
        'author.locality AS "author_locality"',
        'author.city AS "author_city"',
        'comm.id AS "comm_id"',
        'comm.name AS "comm_name"',
        'comm.slug AS "comm_slug"',
        'CASE WHEN userReaction.id IS NOT NULL THEN true ELSE false END AS "currentUserLiked"',
        'ROUND(ST_Distance(post.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) AS distance_meters',
      ])
      .setParameters({
        lng: longitude,
        lat: latitude,
        radiusMeters,
      })
      .where('post.location IS NOT NULL')
      .andWhere('post.deletedAt IS NULL')
      .andWhere(
        '(post.communityId IS NULL OR (comm.visibility = :publicVis AND comm.status = :activeStat))',
        { publicVis: 'public', activeStat: 'active' },
      )
      .andWhere(
        'ST_DWithin(post.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :radiusMeters)',
      );

    if (category) {
      qb.andWhere('post.category = :category', { category });
    }

    // Deterministic cursor pagination: (distance_meters, createdAt, id)
    if (cursor) {
      try {
        const decoded = Buffer.from(cursor, 'base64').toString('utf8');
        const [cursorDistStr, cursorCreatedAtStr, cursorId] = decoded.split(';');
        const cursorDist = parseFloat(cursorDistStr);
        const cursorDate = new Date(cursorCreatedAtStr);

        if (!isNaN(cursorDist) && !isNaN(cursorDate.getTime()) && cursorId) {
          qb.andWhere(
            `(
              ROUND(ST_Distance(post.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) > :cursorDist
              OR (
                ROUND(ST_Distance(post.location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)) = :cursorDist
                AND (post.createdAt < :cursorDate OR (post.createdAt = :cursorDate AND post.id < :cursorId))
              )
            )`,
            { cursorDist, cursorDate, cursorId },
          );
        }
      } catch {
        this.logger.warn(`Malformed nearby cursor: ${cursor}`);
      }
    }

    // Deterministic ordering: closest first, then newest, then tie-break by id
    qb.orderBy('distance_meters', 'ASC')
      .addOrderBy('post.createdAt', 'DESC')
      .addOrderBy('post.id', 'DESC')
      .limit(limit + 1);

    const rawRows: RawNearbyRow[] = await qb.getRawMany();

    const hasMore = rawRows.length > limit;
    const rows = hasMore ? rawRows.slice(0, limit) : rawRows;

    let nextCursor: string | null = null;
    if (hasMore && rows.length > 0) {
      const last = rows[rows.length - 1];
      const dist = parseFloat(last.distance_meters.toString());
      const cDate = new Date(last.createdAt).toISOString();
      nextCursor = Buffer.from(`${dist};${cDate};${last.id}`).toString('base64');
    }

    const items: NearbyPostResponse[] = rows.map((r) => {
      const distMeters = Math.round(parseFloat(r.distance_meters.toString()));
      const { distanceText, distanceMetersRounded } = formatPrivacySafeDistance(distMeters);
      const isLiked =
        r.currentUserLiked === true ||
        r.currentUserLiked === 'true' ||
        r.currentUserLiked === 1;

      return {
        id: r.id,
        authorId: r.authorId,
        author: {
          id: r.author_id ?? r.authorId,
          displayName: r.author_displayName ?? 'Neighbor',
          avatarUrl: r.author_avatarUrl ?? null,
          locality: r.author_locality ?? r.locality ?? null,
          city: r.author_city ?? r.city ?? null,
        },
        content: r.content,
        category: r.category,
        locality: r.locality ?? null,
        neighborhood: r.neighborhood ?? null,
        city: r.city ?? null,
        state: r.state ?? null,
        countryCode: r.countryCode ?? 'IN',
        likeCount: parseInt(r.likeCount.toString(), 10) || 0,
        commentCount: parseInt(r.commentCount.toString(), 10) || 0,
        currentUserLiked: isLiked,
        isOwnPost: r.authorId === currentUserId,
        communityId: r.comm_id ?? null,
        community: r.comm_id
          ? {
              id: r.comm_id,
              name: r.comm_name ?? 'Community',
              slug: r.comm_slug ?? '',
            }
          : null,
        distance: distanceText,
        distanceMeters: distanceMetersRounded,
        createdAt: new Date(r.createdAt),
        updatedAt: new Date(r.updatedAt),
      };
    });

    return {
      items,
      nextCursor,
      hasMore,
      radiusKm,
    };
  }
}

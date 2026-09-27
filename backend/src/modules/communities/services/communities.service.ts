import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  Community,
  CommunityVisibility,
  CommunityStatus,
} from '../entities/community.entity.js';
import {
  CommunityMember,
  CommunityRole,
  CommunityMemberStatus,
} from '../entities/community-member.entity.js';
import { Post, PostCategory } from '../../feed/entities/post.entity.js';
import { ReactionType } from '../../feed/entities/post-reaction.entity.js';
import { User } from '../../users/entities/user.entity.js';
import { Report, ReportTargetType, ReportStatus } from '../../feed/entities/report.entity.js';
import { CreateCommunityDto } from '../dto/create-community.dto.js';
import { UpdateCommunityDto } from '../dto/update-community.dto.js';
import {
  GetCommunitiesQueryDto,
  CommunityDiscoveryScope,
} from '../dto/get-communities-query.dto.js';
import {
  CommunityResponse,
  PaginatedCommunitiesResponse,
} from '../dto/community-response.dto.js';
import {
  CommunityMemberResponse,
  PaginatedCommunityMembersResponse,
} from '../dto/community-member-response.dto.js';
import { CreateCommunityPostDto } from '../dto/create-community-post.dto.js';
import { CreateReportDto } from '../../feed/dto/create-report.dto.js';
import { PostResponse, PaginatedFeedResponse } from '../../feed/services/feed.service.js';
import { RedisService } from '../../../database/redis.service.js';
import { getLocalityCentroid } from '../../localities/utils/locality-centroid.util.js';

@Injectable()
export class CommunitiesService {
  private readonly logger = new Logger(CommunitiesService.name);

  constructor(
    @InjectRepository(Community)
    private readonly communityRepository: Repository<Community>,
    @InjectRepository(CommunityMember)
    private readonly memberRepository: Repository<CommunityMember>,
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Report)
    private readonly reportRepository: Repository<Report>,
    private readonly redisService: RedisService,
  ) {}

  /**
   * Helper to generate a URL-friendly slug from community name.
   */
  private generateBaseSlug(name: string): string {
    return name
      .toLowerCase()
      .trim()
      .replace(/[^\w\s-]/g, '')
      .replace(/[\s_-]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }

  /**
   * Generates a unique slug with collision avoidance.
   */
  private async generateUniqueSlug(name: string): Promise<string> {
    const baseSlug = this.generateBaseSlug(name) || 'community';
    let candidateSlug = baseSlug;
    let attempts = 0;

    while (attempts < 10) {
      const existing = await this.communityRepository.findOne({
        where: { slug: candidateSlug },
      });
      if (!existing) {
        return candidateSlug;
      }
      attempts++;
      const randomSuffix = Math.floor(1000 + Math.random() * 9000);
      candidateSlug = `${baseSlug}-${randomSuffix}`;
    }

    return `${baseSlug}-${Date.now()}`;
  }

  /**
   * Check rate limit using Redis.
   */
  private async checkRateLimit(key: string, limit: number, windowSeconds: number, errorMessage: string) {
    try {
      const count = typeof this.redisService.incrementWithExpire === 'function'
        ? await this.redisService.incrementWithExpire(key, windowSeconds)
        : await this.redisService.incr(key);
      if (count > limit) {
        throw new HttpException(
          {
            code: 'RATE_LIMITED',
            message: errorMessage,
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    } catch (err) {
      if (err instanceof HttpException) throw err;
      this.logger.warn(`Redis rate limit error: ${err}`);
    }
  }

  /**
   * Create a new community. The creator is automatically added as OWNER.
   */
  async createCommunity(
    creatorId: string,
    dto: CreateCommunityDto,
  ): Promise<CommunityResponse> {
    // Rate limit: max 10 communities created per 24 hours per user
    await this.checkRateLimit(
      `rate:comm:create:${creatorId}`,
      10,
      86400,
      'You have reached the maximum number of communities you can create today. Please try again later.',
    );

    const user = await this.userRepository.findOne({ where: { id: creatorId } });
    if (!user) {
      throw new NotFoundException('User not found.');
    }

    const slug = await this.generateUniqueSlug(dto.name);

    // Locality hierarchy defaults from user's onboarded locality if not explicitly given
    const countryCode = dto.countryCode ?? user.countryCode ?? 'IN';
    const state = dto.state ?? user.state ?? null;
    const district = dto.district ?? user.district ?? null;
    const city = dto.city ?? user.city ?? null;
    const locality = dto.locality ?? user.locality ?? null;
    const neighborhood = dto.neighborhood ?? user.neighborhood ?? null;

    const community = this.communityRepository.create({
      name: dto.name.trim(),
      slug,
      description: dto.description.trim(),
      category: dto.category,
      visibility: dto.visibility ?? CommunityVisibility.PUBLIC,
      status: CommunityStatus.ACTIVE,
      creatorId,
      countryCode,
      state,
      district,
      city,
      locality,
      neighborhood,
      coverImageUrl: dto.coverImageUrl ?? null,
      avatarUrl: dto.avatarUrl ?? null,
      memberCount: 1,
      postCount: 0,
    });

    const savedCommunity = await this.communityRepository.save(community);

    // Automatically add creator as OWNER member
    const ownerMember = this.memberRepository.create({
      communityId: savedCommunity.id,
      userId: creatorId,
      role: CommunityRole.OWNER,
      status: CommunityMemberStatus.ACTIVE,
    });
    await this.memberRepository.save(ownerMember);

    return {
      id: savedCommunity.id,
      name: savedCommunity.name,
      slug: savedCommunity.slug,
      description: savedCommunity.description,
      category: savedCommunity.category,
      visibility: savedCommunity.visibility,
      status: savedCommunity.status,
      creatorId: savedCommunity.creatorId,
      creator: {
        id: user.id,
        displayName: user.displayName ?? 'Neighbor',
        avatarUrl: user.avatarUrl ?? null,
      },
      countryCode: savedCommunity.countryCode,
      state: savedCommunity.state,
      district: savedCommunity.district,
      city: savedCommunity.city,
      locality: savedCommunity.locality,
      neighborhood: savedCommunity.neighborhood,
      memberCount: 1,
      postCount: 0,
      coverImageUrl: savedCommunity.coverImageUrl,
      avatarUrl: savedCommunity.avatarUrl,
      currentUserMember: true,
      currentUserRole: CommunityRole.OWNER,
      createdAt: savedCommunity.createdAt,
      updatedAt: savedCommunity.updatedAt,
    };
  }

  /**
   * Discover and list paginated communities with deterministic cursor, locality scoping, and search.
   */
  async getCommunities(
    currentUserId: string,
    query: GetCommunitiesQueryDto,
  ): Promise<PaginatedCommunitiesResponse> {
    const limit = query.limit ?? 20;
    const currentUser = await this.userRepository.findOne({ where: { id: currentUserId } });

    const qb = this.communityRepository
      .createQueryBuilder('comm')
      .leftJoinAndSelect('comm.creator', 'creator')
      .leftJoin(
        'community_members',
        'myMembership',
        'myMembership.communityId = comm.id AND myMembership.userId = :currentUserId AND myMembership.status = :activeStatus',
        { currentUserId, activeStatus: CommunityMemberStatus.ACTIVE },
      )
      .addSelect('CASE WHEN myMembership.id IS NOT NULL THEN true ELSE false END', 'currentUserMember')
      .addSelect('myMembership.role', 'currentUserRole')
      .where('comm.status = :activeCommStatus', { activeCommStatus: CommunityStatus.ACTIVE });

    // 1. Scope filter
    if (query.scope === CommunityDiscoveryScope.JOINED || query.joinedOnly === true) {
      qb.andWhere('myMembership.id IS NOT NULL');
    } else if (query.scope === CommunityDiscoveryScope.LOCAL && currentUser?.city) {
      qb.andWhere('(comm.city = :city OR comm.locality = :locality)', {
        city: currentUser.city,
        locality: currentUser.locality ?? '',
      });
    }

    // 2. Category filter
    if (query.category) {
      qb.andWhere('comm.category = :category', { category: query.category });
    }

    // 3. Visibility filter
    if (query.visibility) {
      qb.andWhere('comm.visibility = :visibility', { visibility: query.visibility });
    }

    // 4. Locality / City filter
    if (query.city) {
      qb.andWhere('LOWER(comm.city) = LOWER(:qCity)', { qCity: query.city });
    }
    if (query.locality) {
      qb.andWhere('LOWER(comm.locality) = LOWER(:qLocality)', { qLocality: query.locality });
    }

    // 5. Search query (case-insensitive name, description, slug)
    if (query.search && query.search.trim().length > 0) {
      const term = `%${query.search.trim().toLowerCase()}%`;
      qb.andWhere(
        '(LOWER(comm.name) LIKE :term OR LOWER(comm.description) LIKE :term OR LOWER(comm.slug) LIKE :term)',
        { term },
      );
    }

    // 6. Deterministic cursor pagination (createdAt DESC, id DESC)
    if (query.cursor) {
      try {
        const decoded = Buffer.from(query.cursor, 'base64').toString('utf8');
        const [cursorTimestamp, cursorId] = decoded.split(',');
        const cursorDate = new Date(cursorTimestamp);
        if (!isNaN(cursorDate.getTime()) && cursorId) {
          qb.andWhere(
            '(comm.createdAt < :cursorDate OR (comm.createdAt = :cursorDate AND comm.id < :cursorId))',
            { cursorDate, cursorId },
          );
        }
      } catch {
        this.logger.warn(`Malformed cursor received: ${query.cursor}`);
      }
    }

    qb.orderBy('comm.createdAt', 'DESC')
      .addOrderBy('comm.id', 'DESC')
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

    const communities: CommunityResponse[] = pageEntities.map((comm, index) => {
      const rawRow = pageRaw[index];
      const isMember =
        rawRow?.currentUserMember === true ||
        rawRow?.currentUserMember === 'true' ||
        rawRow?.currentUserMember === 1;
      const role = rawRow?.currentUserRole as CommunityRole | null;

      return {
        id: comm.id,
        name: comm.name,
        slug: comm.slug,
        description: comm.description,
        category: comm.category,
        visibility: comm.visibility,
        status: comm.status,
        creatorId: comm.creatorId,
        creator: {
          id: comm.creator?.id ?? comm.creatorId,
          displayName: comm.creator?.displayName ?? 'Neighbor',
          avatarUrl: comm.creator?.avatarUrl ?? null,
        },
        countryCode: comm.countryCode,
        state: comm.state,
        district: comm.district,
        city: comm.city,
        locality: comm.locality,
        neighborhood: comm.neighborhood,
        memberCount: comm.memberCount,
        postCount: comm.postCount,
        coverImageUrl: comm.coverImageUrl,
        avatarUrl: comm.avatarUrl,
        currentUserMember: isMember,
        currentUserRole: isMember ? (role ?? CommunityRole.MEMBER) : null,
        createdAt: comm.createdAt,
        updatedAt: comm.updatedAt,
      };
    });

    return {
      communities,
      nextCursor,
      hasMore,
    };
  }

  /**
   * Get single community details with membership status.
   */
  async getCommunityById(
    communityId: string,
    currentUserId: string,
  ): Promise<CommunityResponse> {
    const comm = await this.communityRepository.findOne({
      where: { id: communityId },
      relations: ['creator'],
    });

    if (!comm) {
      throw new NotFoundException('Community not found.');
    }

    if (comm.status === CommunityStatus.SUSPENDED) {
      throw new ForbiddenException('This community has been suspended by administration.');
    }

    const membership = await this.memberRepository.findOne({
      where: {
        communityId,
        userId: currentUserId,
        status: CommunityMemberStatus.ACTIVE,
      },
    });

    return {
      id: comm.id,
      name: comm.name,
      slug: comm.slug,
      description: comm.description,
      category: comm.category,
      visibility: comm.visibility,
      status: comm.status,
      creatorId: comm.creatorId,
      creator: {
        id: comm.creator?.id ?? comm.creatorId,
        displayName: comm.creator?.displayName ?? 'Neighbor',
        avatarUrl: comm.creator?.avatarUrl ?? null,
      },
      countryCode: comm.countryCode,
      state: comm.state,
      district: comm.district,
      city: comm.city,
      locality: comm.locality,
      neighborhood: comm.neighborhood,
      memberCount: comm.memberCount,
      postCount: comm.postCount,
      coverImageUrl: comm.coverImageUrl,
      avatarUrl: comm.avatarUrl,
      currentUserMember: !!membership,
      currentUserRole: membership ? membership.role : null,
      createdAt: comm.createdAt,
      updatedAt: comm.updatedAt,
    };
  }

  /**
   * Update community details (Owner / Moderator only).
   */
  async updateCommunity(
    communityId: string,
    currentUserId: string,
    dto: UpdateCommunityDto,
  ): Promise<CommunityResponse> {
    const comm = await this.communityRepository.findOne({
      where: { id: communityId },
      relations: ['creator'],
    });

    if (!comm) {
      throw new NotFoundException('Community not found.');
    }

    if (comm.status === CommunityStatus.SUSPENDED) {
      throw new ForbiddenException('Cannot edit a suspended community.');
    }

    if (comm.status === CommunityStatus.ARCHIVED && dto.status !== CommunityStatus.ACTIVE) {
      throw new ForbiddenException('Cannot edit an archived community unless reactivating it.');
    }

    const membership = await this.memberRepository.findOne({
      where: {
        communityId,
        userId: currentUserId,
        status: CommunityMemberStatus.ACTIVE,
      },
    });

    if (!membership || (membership.role !== CommunityRole.OWNER && membership.role !== CommunityRole.MODERATOR)) {
      throw new ForbiddenException('You do not have permission to manage this community.');
    }

    if (dto.status !== undefined) {
      if (dto.status === CommunityStatus.SUSPENDED) {
        throw new ForbiddenException('Only system moderators can suspend a community.');
      }
      comm.status = dto.status;
    }
    if (dto.name !== undefined && dto.name.trim().length > 0) {
      comm.name = dto.name.trim();
    }
    if (dto.description !== undefined && dto.description.trim().length > 0) {
      comm.description = dto.description.trim();
    }
    if (dto.category !== undefined) {
      comm.category = dto.category;
    }
    if (dto.visibility !== undefined) {
      comm.visibility = dto.visibility;
    }
    if (dto.coverImageUrl !== undefined) {
      comm.coverImageUrl = dto.coverImageUrl;
    }
    if (dto.avatarUrl !== undefined) {
      comm.avatarUrl = dto.avatarUrl;
    }

    const updated = await this.communityRepository.save(comm);

    return {
      id: updated.id,
      name: updated.name,
      slug: updated.slug,
      description: updated.description,
      category: updated.category,
      visibility: updated.visibility,
      status: updated.status,
      creatorId: updated.creatorId,
      creator: {
        id: updated.creator?.id ?? updated.creatorId,
        displayName: updated.creator?.displayName ?? 'Neighbor',
        avatarUrl: updated.creator?.avatarUrl ?? null,
      },
      countryCode: updated.countryCode,
      state: updated.state,
      district: updated.district,
      city: updated.city,
      locality: updated.locality,
      neighborhood: updated.neighborhood,
      memberCount: updated.memberCount,
      postCount: updated.postCount,
      coverImageUrl: updated.coverImageUrl,
      avatarUrl: updated.avatarUrl,
      currentUserMember: true,
      currentUserRole: membership.role,
      createdAt: updated.createdAt,
      updatedAt: updated.updatedAt,
    };
  }

  /**
   * Join a community (idempotent).
   */
  async joinCommunity(
    communityId: string,
    currentUserId: string,
  ): Promise<{ message: string; role: CommunityRole }> {
    // Rate limit: max 30 join operations per hour
    await this.checkRateLimit(
      `rate:comm:join:${currentUserId}`,
      30,
      3600,
      'You are joining communities too quickly. Please wait a few moments before trying again.',
    );

    const comm = await this.communityRepository.findOne({ where: { id: communityId } });
    if (!comm) {
      throw new NotFoundException('Community not found.');
    }

    if (comm.status !== CommunityStatus.ACTIVE) {
      throw new ForbiddenException('Cannot join an unavailable or suspended community.');
    }

    const existingMember = await this.memberRepository.findOne({
      where: { communityId, userId: currentUserId },
    });

    if (existingMember) {
      if (existingMember.status === CommunityMemberStatus.ACTIVE) {
        return {
          message: 'You are already a member of this community.',
          role: existingMember.role,
        };
      }
      if (existingMember.status === CommunityMemberStatus.BANNED) {
        throw new ForbiddenException('You have been banned from this community.');
      }
      // Re-activate pending/inactive membership
      existingMember.status = CommunityMemberStatus.ACTIVE;
      await this.memberRepository.save(existingMember);
      await this.communityRepository.increment({ id: communityId }, 'memberCount', 1);
      return {
        message: 'Welcome back to the community!',
        role: existingMember.role,
      };
    }

    // New membership
    const newMember = this.memberRepository.create({
      communityId,
      userId: currentUserId,
      role: CommunityRole.MEMBER,
      status: CommunityMemberStatus.ACTIVE,
    });
    await this.memberRepository.save(newMember);
    await this.communityRepository.increment({ id: communityId }, 'memberCount', 1);

    return {
      message: 'Successfully joined the community.',
      role: CommunityRole.MEMBER,
    };
  }

  /**
   * Leave a community. Owners cannot leave without transferring ownership.
   */
  async leaveCommunity(
    communityId: string,
    currentUserId: string,
  ): Promise<{ message: string }> {
    const membership = await this.memberRepository.findOne({
      where: { communityId, userId: currentUserId, status: CommunityMemberStatus.ACTIVE },
    });

    if (!membership) {
      throw new NotFoundException('You are not an active member of this community.');
    }

    if (membership.role === CommunityRole.OWNER) {
      throw new BadRequestException(
        'As the owner of this community, you cannot leave directly. Please transfer ownership or delete the community.',
      );
    }

    await this.memberRepository.remove(membership);
    await this.communityRepository.decrement({ id: communityId }, 'memberCount', 1);

    return { message: 'Successfully left the community.' };
  }

  /**
   * Get current user's membership state.
   */
  async getMembership(
    communityId: string,
    currentUserId: string,
  ): Promise<{ isMember: boolean; role: CommunityRole | null; joinedAt: Date | null }> {
    const membership = await this.memberRepository.findOne({
      where: { communityId, userId: currentUserId, status: CommunityMemberStatus.ACTIVE },
    });

    if (!membership) {
      return { isMember: false, role: null, joinedAt: null };
    }

    return {
      isMember: true,
      role: membership.role,
      joinedAt: membership.joinedAt,
    };
  }

  /**
   * List paginated members of a community. Private communities require membership.
   * Privacy-safe: Never exposes phone, email, or exact coordinates.
   */
  async getMembers(
    communityId: string,
    currentUserId: string,
    limit: number = 20,
    cursor?: string,
  ): Promise<PaginatedCommunityMembersResponse> {
    const comm = await this.communityRepository.findOne({ where: { id: communityId } });
    if (!comm) {
      throw new NotFoundException('Community not found.');
    }

    if (comm.status !== CommunityStatus.ACTIVE) {
      throw new ForbiddenException('Community is not active.');
    }

    // Private community check
    if (comm.visibility === CommunityVisibility.PRIVATE) {
      const isMember = await this.memberRepository.findOne({
        where: { communityId, userId: currentUserId, status: CommunityMemberStatus.ACTIVE },
      });
      if (!isMember) {
        throw new ForbiddenException('Membership is required to view members of this private community.');
      }
    }

    const qb = this.memberRepository
      .createQueryBuilder('member')
      .leftJoinAndSelect('member.user', 'user')
      .where('member.communityId = :communityId', { communityId })
      .andWhere('member.status = :activeStatus', { activeStatus: CommunityMemberStatus.ACTIVE });

    // Cursor pagination (joinedAt DESC, id DESC)
    if (cursor) {
      try {
        const decoded = Buffer.from(cursor, 'base64').toString('utf8');
        const [cursorTimestamp, cursorId] = decoded.split(',');
        const cursorDate = new Date(cursorTimestamp);
        if (!isNaN(cursorDate.getTime()) && cursorId) {
          qb.andWhere(
            '(member.joinedAt < :cursorDate OR (member.joinedAt = :cursorDate AND member.id < :cursorId))',
            { cursorDate, cursorId },
          );
        }
      } catch {
        this.logger.warn(`Malformed cursor received: ${cursor}`);
      }
    }

    qb.orderBy('member.joinedAt', 'DESC')
      .addOrderBy('member.id', 'DESC')
      .take(limit + 1);

    const entities = await qb.getMany();
    const hasMore = entities.length > limit;
    const pageEntities = hasMore ? entities.slice(0, limit) : entities;

    let nextCursor: string | undefined;
    if (hasMore && pageEntities.length > 0) {
      const last = pageEntities[pageEntities.length - 1];
      const rawCursor = `${last.joinedAt.toISOString()},${last.id}`;
      nextCursor = Buffer.from(rawCursor).toString('base64');
    }

    const members: CommunityMemberResponse[] = pageEntities.map((m) => ({
      id: m.id,
      communityId: m.communityId,
      userId: m.userId,
      role: m.role,
      status: m.status,
      user: {
        id: m.user?.id ?? m.userId,
        displayName: m.user?.displayName ?? 'Neighbor',
        avatarUrl: m.user?.avatarUrl ?? null,
        locality: m.user?.locality ?? null,
        city: m.user?.city ?? null,
      },
      joinedAt: m.joinedAt,
    }));

    return {
      members,
      nextCursor,
      hasMore,
    };
  }

  /**
   * List paginated posts within a community.
   * Private communities require membership.
   */
  async getCommunityPosts(
    communityId: string,
    currentUserId: string,
    limit: number = 20,
    cursor?: string,
  ): Promise<PaginatedFeedResponse> {
    const comm = await this.communityRepository.findOne({ where: { id: communityId } });
    if (!comm) {
      throw new NotFoundException('Community not found.');
    }

    if (comm.status !== CommunityStatus.ACTIVE) {
      throw new ForbiddenException('Community is not active.');
    }

    // Private community check
    if (comm.visibility === CommunityVisibility.PRIVATE) {
      const isMember = await this.memberRepository.findOne({
        where: { communityId, userId: currentUserId, status: CommunityMemberStatus.ACTIVE },
      });
      if (!isMember) {
        throw new ForbiddenException('Membership is required to view posts in this private community.');
      }
    }

    const qb = this.postRepository
      .createQueryBuilder('post')
      .leftJoinAndSelect('post.author', 'author')
      .leftJoin(
        'post_reactions',
        'userReaction',
        'userReaction.postId = post.id AND userReaction.userId = :currentUserId AND userReaction.reactionType = :like',
        { currentUserId, like: ReactionType.LIKE },
      )
      .addSelect('CASE WHEN userReaction.id IS NOT NULL THEN true ELSE false END', 'currentUserLiked')
      .where('post.communityId = :communityId', { communityId })
      .andWhere('post.deletedAt IS NULL');

    // Cursor pagination (createdAt DESC, id DESC)
    if (cursor) {
      try {
        const decoded = Buffer.from(cursor, 'base64').toString('utf8');
        const [cursorTimestamp, cursorId] = decoded.split(',');
        const cursorDate = new Date(cursorTimestamp);
        if (!isNaN(cursorDate.getTime()) && cursorId) {
          qb.andWhere(
            '(post.createdAt < :cursorDate OR (post.createdAt = :cursorDate AND post.id < :cursorId))',
            { cursorDate, cursorId },
          );
        }
      } catch {
        this.logger.warn(`Malformed cursor received: ${cursor}`);
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

      return {
        id: post.id,
        authorId: post.authorId,
        author: {
          id: post.author?.id ?? post.authorId,
          displayName: post.author?.displayName ?? 'Neighbor',
          avatarUrl: post.author?.avatarUrl ?? null,
          locality: post.author?.locality ?? null,
          city: post.author?.city ?? null,
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
        communityId: post.communityId ?? null,
        community: {
          id: comm.id,
          name: comm.name,
          slug: comm.slug,
        },
        createdAt: post.createdAt,
        updatedAt: post.updatedAt,
      };
    });

    return {
      posts,
      nextCursor,
      hasMore,
      scope: `community:${comm.slug}`,
    };
  }

  /**
   * Create a post inside a community.
   * User MUST be an active member of the community.
   */
  async createCommunityPost(
    communityId: string,
    currentUserId: string,
    dto: CreateCommunityPostDto,
  ): Promise<PostResponse> {
    const comm = await this.communityRepository.findOne({ where: { id: communityId } });
    if (!comm) {
      throw new NotFoundException('Community not found.');
    }

    if (comm.status !== CommunityStatus.ACTIVE) {
      throw new ForbiddenException('Cannot post to an unavailable or suspended community.');
    }

    // Membership check: only members can post
    const membership = await this.memberRepository.findOne({
      where: { communityId, userId: currentUserId, status: CommunityMemberStatus.ACTIVE },
    });
    if (!membership) {
      throw new ForbiddenException('You must be a member of this community to post.');
    }

    // Rate limiting: 10 posts per 10 minutes
    await this.checkRateLimit(
      `rate:comm:post:${currentUserId}`,
      10,
      600,
      'You are posting too frequently. Please wait a few minutes before posting again.',
    );

    const user = await this.userRepository.findOne({ where: { id: currentUserId } });
    if (!user) {
      throw new NotFoundException('User not found.');
    }

    // Inherit locality from community or user
    const city = comm.city ?? user.city ?? null;
    const locality = comm.locality ?? user.locality ?? null;
    const state = comm.state ?? user.state ?? null;
    const district = comm.district ?? user.district ?? null;
    const countryCode = comm.countryCode ?? user.countryCode ?? 'IN';
    const neighborhood = comm.neighborhood ?? user.neighborhood ?? null;

    // Centroid for spatial queries if available
    const centroid = locality ? getLocalityCentroid(locality, city ?? undefined) : null;

    const post = this.postRepository.create({
      authorId: currentUserId,
      content: dto.content.trim(),
      category: dto.category ?? PostCategory.GENERAL,
      communityId,
      countryCode,
      state,
      district,
      city,
      locality,
      neighborhood,
      likeCount: 0,
      commentCount: 0,
    });

    if (centroid) {
      post.location = () => `ST_SetSRID(ST_MakePoint(${centroid.longitude}, ${centroid.latitude}), 4326)::geography`;
    }

    const savedPost = await this.postRepository.save(post);
    await this.communityRepository.increment({ id: communityId }, 'postCount', 1);

    return {
      id: savedPost.id,
      authorId: currentUserId,
      author: {
        id: user.id,
        displayName: user.displayName ?? 'Neighbor',
        avatarUrl: user.avatarUrl ?? null,
        locality: user.locality ?? null,
        city: user.city ?? null,
      },
      content: savedPost.content,
      category: savedPost.category,
      countryCode: savedPost.countryCode,
      state: savedPost.state ?? null,
      district: savedPost.district ?? null,
      city: savedPost.city ?? null,
      locality: savedPost.locality ?? null,
      neighborhood: savedPost.neighborhood ?? null,
      likeCount: 0,
      commentCount: 0,
      currentUserLiked: false,
      isOwnPost: true,
      communityId,
      community: {
        id: comm.id,
        name: comm.name,
        slug: comm.slug,
      },
      createdAt: savedPost.createdAt,
      updatedAt: savedPost.updatedAt,
    };
  }

  /**
   * Report a community for trust & safety review.
   */
  async reportCommunity(
    communityId: string,
    reporterId: string,
    dto: CreateReportDto,
  ): Promise<{ message: string }> {
    const comm = await this.communityRepository.findOne({ where: { id: communityId } });
    if (!comm) {
      throw new NotFoundException('Community not found.');
    }

    // Rate limit reports: max 10 per hour
    await this.checkRateLimit(
      `rate:report:${reporterId}`,
      10,
      3600,
      'Too many reports submitted. Please wait before reporting again.',
    );

    const existing = await this.reportRepository.findOne({
      where: {
        reporterId,
        targetType: ReportTargetType.COMMUNITY,
        targetId: communityId,
      },
    });

    if (existing) {
      throw new ConflictException('You have already submitted a report for this community.');
    }

    const report = this.reportRepository.create({
      reporterId,
      targetType: ReportTargetType.COMMUNITY,
      targetId: communityId,
      reason: dto.reason,
      details: dto.details ?? null,
      status: ReportStatus.PENDING,
    });

    await this.reportRepository.save(report);

    return { message: 'Thank you. Your report has been submitted for review.' };
  }
}

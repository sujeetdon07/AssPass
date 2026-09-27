import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Event, EventCategory, EventStatus } from './entities/event.entity.js';
import { EventRsvp, EventRsvpStatus } from './entities/event-rsvp.entity.js';
import { Community, CommunityVisibility } from '../communities/entities/community.entity.js';
import { CommunityMember } from '../communities/entities/community-member.entity.js';
import { User } from '../users/entities/user.entity.js';
import { RedisService } from '../../database/redis.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { NotificationType } from '../notifications/enums/notification-type.enum.js';
import { NotificationCategory } from '../notifications/enums/notification-category.enum.js';
import { CreateEventDto } from './dto/create-event.dto.js';
import { UpdateEventDto } from './dto/update-event.dto.js';
import { CancelEventDto } from './dto/cancel-event.dto.js';
import { RsvpEventDto } from './dto/rsvp-event.dto.js';
import { GetEventsQueryDto, EventTimeFrame } from './dto/get-events-query.dto.js';
import {
  EventResponseDto,
  PaginatedEventsResponseDto,
  PaginatedParticipantsResponseDto,
  EventParticipantDto,
} from './dto/event-response.dto.js';

@Injectable()
export class EventsService {
  private readonly logger = new Logger(EventsService.name);

  // Rate limiting configuration
  private readonly createRateLimitMax = 10;
  private readonly createRateLimitWindowSeconds = 3600; // 10/hour
  private readonly rsvpRateLimitMax = 30;
  private readonly rsvpRateLimitWindowSeconds = 60; // 30/minute

  constructor(
    @InjectRepository(Event)
    private readonly eventRepo: Repository<Event>,
    @InjectRepository(EventRsvp)
    private readonly rsvpRepo: Repository<EventRsvp>,
    @InjectRepository(Community)
    private readonly communityRepo: Repository<Community>,
    @InjectRepository(CommunityMember)
    private readonly communityMemberRepo: Repository<CommunityMember>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly redisService: RedisService,
    private readonly notificationsService: NotificationsService,
  ) {}

  /**
   * Create a new event.
   */
  async createEvent(userId: string, dto: CreateEventDto): Promise<EventResponseDto> {
    await this.checkRateLimit(`events:create:rate:${userId}`, this.createRateLimitMax, this.createRateLimitWindowSeconds);

    const start = new Date(dto.startAt);
    const end = new Date(dto.endAt);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Invalid start or end date format.');
    }
    if (end < start) {
      throw new BadRequestException('Event end date/time must be after start date/time.');
    }

    // Community validation if communityId is provided
    let community: Community | null = null;
    if (dto.communityId) {
      community = await this.communityRepo.findOne({ where: { id: dto.communityId } });
      if (!community) {
        throw new NotFoundException('Specified community not found.');
      }
      if (community.visibility === CommunityVisibility.PRIVATE) {
        const isMember = await this.isCommunityMember(dto.communityId, userId);
        if (!isMember) {
          throw new ForbiddenException('You must be a member of this private community to host events in it.');
        }
      }
    }

    // Fetch user for locality defaults if not provided
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found.');
    }

    const locality = dto.locality ?? user.locality ?? null;
    const city = dto.city ?? user.city ?? null;
    const state = dto.state ?? user.state ?? null;

    // Create event record
    const event = this.eventRepo.create({
      creatorId: userId,
      communityId: dto.communityId ?? null,
      title: dto.title.trim(),
      description: dto.description.trim(),
      category: dto.category ?? EventCategory.NEIGHBORHOOD,
      status: EventStatus.ACTIVE,
      startAt: start,
      endAt: end,
      timezone: dto.timezone ?? 'Asia/Kolkata',
      venue: dto.venue.trim(),
      address: dto.address.trim(),
      locality,
      city,
      state,
      countryCode: 'IN',
      coverImageUrl: dto.coverImageUrl ?? null,
      participantCount: 1, // Organizer automatically RSVPs
    });

    if (dto.latitude !== undefined && dto.longitude !== undefined) {
      event.location = () =>
        `ST_SetSRID(ST_MakePoint(${Number(dto.longitude)}, ${Number(dto.latitude)}), 4326)::geography`;
    }

    const savedEvent = await this.eventRepo.save(event);

    // Auto-RSVP the creator as "going"
    const rsvp = this.rsvpRepo.create({
      eventId: savedEvent.id,
      userId,
      status: EventRsvpStatus.GOING,
    });
    await this.rsvpRepo.save(rsvp);

    this.logger.log(`[EventsService] Event created: ${savedEvent.id} by user ${userId}`);

    return this.getEventById(savedEvent.id, userId);
  }

  /**
   * Get paginated discovery events with filters (locality, community, category, radius, upcoming).
   */
  async getEvents(
    currentUserId: string,
    query: GetEventsQueryDto,
  ): Promise<PaginatedEventsResponseDto> {
    const limit = query.limit ? Math.min(Math.max(Number(query.limit), 1), 50) : 20;
    const now = new Date();

    const qb = this.eventRepo
      .createQueryBuilder('e')
      .leftJoinAndSelect('e.creator', 'creator')
      .leftJoinAndSelect('e.community', 'community')
      .where('e.deletedAt IS NULL');

    // Status filter (default: active)
    if (query.status) {
      qb.andWhere('e.status = :status', { status: query.status });
    } else {
      qb.andWhere('e.status = :status', { status: EventStatus.ACTIVE });
    }

    // Timeframe filter (upcoming vs past vs all)
    const timeFrame = query.timeframe ?? query.timeFrame ?? EventTimeFrame.UPCOMING;
    if (timeFrame === EventTimeFrame.UPCOMING) {
      qb.andWhere('e.endAt >= :now', { now });
    } else if (timeFrame === EventTimeFrame.PAST) {
      qb.andWhere('e.endAt < :now', { now });
    }

    // Community filter
    if (query.communityId) {
      // Validate community access
      const comm = await this.communityRepo.findOne({ where: { id: query.communityId } });
      if (comm && comm.visibility === CommunityVisibility.PRIVATE) {
        const isMember = await this.isCommunityMember(query.communityId, currentUserId);
        if (!isMember) {
          throw new ForbiddenException('Cannot view events for private community you have not joined.');
        }
      }
      qb.andWhere('e.communityId = :communityId', { communityId: query.communityId });
    } else {
      // General discovery: hide events belonging to private communities that the user is not a member of
      qb.andWhere(
        `(e.communityId IS NULL OR community.visibility = 'public' OR EXISTS (
          SELECT 1 FROM community_members cm
          WHERE cm."communityId" = e."communityId"
            AND cm."userId" = :currentUserId
            AND cm."status" = 'active'
        ))`,
        { currentUserId },
      );
    }

    // Category filter
    if (query.category) {
      qb.andWhere('e.category = :category', { category: query.category });
    }

    // Locality filter
    if (query.locality) {
      qb.andWhere('LOWER(e.locality) = LOWER(:locality)', { locality: query.locality });
    }

    // Keyword search
    if (query.search && query.search.trim().length > 0) {
      const s = `%${query.search.trim().toLowerCase()}%`;
      qb.andWhere(
        '(LOWER(e.title) LIKE :s OR LOWER(e.description) LIKE :s OR LOWER(e.venue) LIKE :s)',
        { s },
      );
    }

    // PostGIS spatial radius discovery
    const hasCoords = query.latitude !== undefined && query.longitude !== undefined;
    if (hasCoords) {
      const radiusMeters = (query.radiusKm ?? 10) * 1000;
      qb.andWhere(
        `e.location IS NOT NULL AND ST_DWithin(
          e.location,
          ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
          :radiusMeters
        )`,
        {
          lon: Number(query.longitude),
          lat: Number(query.latitude),
          radiusMeters,
        },
      );
      qb.addSelect(
        `ROUND(ST_Distance(
          e.location,
          ST_SetSRID(ST_MakePoint(${Number(query.longitude)}, ${Number(query.latitude)}), 4326)::geography
        ))`,
        'distance_meters',
      );
    }

    // Ordering and Cursor pagination
    if (timeFrame === EventTimeFrame.UPCOMING) {
      qb.orderBy('e.startAt', 'ASC').addOrderBy('e.id', 'ASC');
      if (query.cursor) {
        const [cursorDateStr, cursorId] = query.cursor.split('|');
        if (cursorDateStr && cursorId) {
          const cursorDate = new Date(cursorDateStr);
          qb.andWhere(
            '(e.startAt > :cursorDate OR (e.startAt = :cursorDate AND e.id > :cursorId))',
            { cursorDate, cursorId },
          );
        }
      }
    } else {
      qb.orderBy('e.startAt', 'DESC').addOrderBy('e.id', 'DESC');
      if (query.cursor) {
        const [cursorDateStr, cursorId] = query.cursor.split('|');
        if (cursorDateStr && cursorId) {
          const cursorDate = new Date(cursorDateStr);
          qb.andWhere(
            '(e.startAt < :cursorDate OR (e.startAt = :cursorDate AND e.id < :cursorId))',
            { cursorDate, cursorId },
          );
        }
      }
    }

    qb.take(limit + 1);

    const rawAndEntities = await qb.getRawAndEntities();
    const entities = rawAndEntities.entities;
    const hasMore = entities.length > limit;
    const items = hasMore ? entities.slice(0, limit) : entities;

    // Collect caller RSVPs for returned items
    const eventIds = items.map((e) => e.id);
    let userRsvps: Record<string, EventRsvpStatus> = {};
    if (eventIds.length > 0) {
      const rsvps = await this.rsvpRepo.find({
        where: { eventId: In(eventIds), userId: currentUserId },
      });
      userRsvps = rsvps.reduce((acc, r) => {
        acc[r.eventId] = r.status;
        return acc;
      }, {} as Record<string, EventRsvpStatus>);
    }

    // Distance map from raw query results if geo search was used
    const distanceMap: Record<string, number> = {};
    if (hasCoords) {
      for (const raw of rawAndEntities.raw) {
        if (raw.e_id && raw.distance_meters !== undefined && raw.distance_meters !== null) {
          distanceMap[raw.e_id] = Number(raw.distance_meters);
        }
      }
    }

    const responseItems: EventResponseDto[] = items.map((event) => {
      const distance = distanceMap[event.id] ?? null;
      return this.formatEventResponse(event, userRsvps[event.id] ?? null, distance, currentUserId);
    });

    let nextCursor: string | null = null;
    if (hasMore && items.length > 0) {
      const last = items[items.length - 1]!;
      nextCursor = `${last.startAt.toISOString()}|${last.id}`;
    }

    return { items: responseItems, nextCursor, hasMore };
  }

  /**
   * Get details of a single event by ID.
   */
  async getEventById(
    id: string,
    currentUserId: string,
    userLat?: number,
    userLon?: number,
  ): Promise<EventResponseDto> {
    const qb = this.eventRepo
      .createQueryBuilder('e')
      .leftJoinAndSelect('e.creator', 'creator')
      .leftJoinAndSelect('e.community', 'community')
      .where('e.id = :id', { id })
      .andWhere('e.deletedAt IS NULL');

    if (userLat !== undefined && userLon !== undefined) {
      qb.addSelect(
        `ROUND(ST_Distance(
          e.location,
          ST_SetSRID(ST_MakePoint(${Number(userLon)}, ${Number(userLat)}), 4326)::geography
        ))`,
        'distance_meters',
      );
    }

    const rawAndEntities = await qb.getRawAndEntities();
    const event = rawAndEntities.entities[0];

    if (!event) {
      throw new NotFoundException('Event not found.');
    }

    // Verify private community authorization
    if (event.community && event.community.visibility === CommunityVisibility.PRIVATE) {
      const isMember = await this.isCommunityMember(event.community.id, currentUserId);
      if (!isMember) {
        throw new ForbiddenException('Cannot view event for private community you have not joined.');
      }
    }

    // Get caller RSVP status
    const rsvp = await this.rsvpRepo.findOne({
      where: { eventId: id, userId: currentUserId },
    });

    const rawDistance = rawAndEntities.raw[0]?.distance_meters;
    const distanceMeters = rawDistance !== undefined && rawDistance !== null ? Number(rawDistance) : null;

    return this.formatEventResponse(event, rsvp?.status ?? null, distanceMeters, currentUserId);
  }

  /**
   * Update event details (Organizer only).
   */
  async updateEvent(
    id: string,
    userId: string,
    dto: UpdateEventDto,
  ): Promise<EventResponseDto> {
    const event = await this.eventRepo.findOne({ where: { id } });
    if (!event) {
      throw new NotFoundException('Event not found.');
    }

    if (event.creatorId !== userId) {
      throw new ForbiddenException('You do not have permission to edit this event.');
    }

    if (event.status === EventStatus.CANCELLED) {
      throw new BadRequestException('Cannot edit a cancelled event.');
    }

    if (dto.title) event.title = dto.title.trim();
    if (dto.description) event.description = dto.description.trim();
    if (dto.category) event.category = dto.category;
    if (dto.venue) event.venue = dto.venue.trim();
    if (dto.address) event.address = dto.address.trim();
    if (dto.locality !== undefined) event.locality = dto.locality;
    if (dto.city !== undefined) event.city = dto.city;
    if (dto.state !== undefined) event.state = dto.state;
    if (dto.timezone) event.timezone = dto.timezone;
    if (dto.coverImageUrl !== undefined) event.coverImageUrl = dto.coverImageUrl;

    if (dto.startAt || dto.endAt) {
      const start = dto.startAt ? new Date(dto.startAt) : event.startAt;
      const end = dto.endAt ? new Date(dto.endAt) : event.endAt;
      if (isNaN(start.getTime()) || isNaN(end.getTime())) {
        throw new BadRequestException('Invalid start or end date format.');
      }
      if (end < start) {
        throw new BadRequestException('Event end date/time must be after start date/time.');
      }
      event.startAt = start;
      event.endAt = end;
    }

    if (dto.latitude !== undefined && dto.longitude !== undefined) {
      event.location = () =>
        `ST_SetSRID(ST_MakePoint(${Number(dto.longitude)}, ${Number(dto.latitude)}), 4326)::geography`;
    }

    await this.eventRepo.save(event);
    this.logger.log(`[EventsService] Event updated: ${id} by user ${userId}`);

    return this.getEventById(id, userId);
  }

  /**
   * Cancel an event (Organizer only). Notifies all participants who RSVP'd.
   */
  async cancelEvent(
    id: string,
    userId: string,
    dto: CancelEventDto,
  ): Promise<EventResponseDto> {
    const event = await this.eventRepo.findOne({ where: { id } });
    if (!event) {
      throw new NotFoundException('Event not found.');
    }

    if (event.creatorId !== userId) {
      throw new ForbiddenException('You do not have permission to cancel this event.');
    }

    if (event.status === EventStatus.CANCELLED) {
      throw new BadRequestException('Event is already cancelled.');
    }

    event.status = EventStatus.CANCELLED;
    event.cancelledAt = new Date();
    event.cancellationReason = dto.reason?.trim() ?? 'Event was cancelled by organizer.';

    await this.eventRepo.save(event);
    this.logger.log(`[EventsService] Event cancelled: ${id} by user ${userId}`);

    // Notify all participants who RSVP'd "going" or "interested"
    const rsvps = await this.rsvpRepo.find({
      where: { eventId: id },
    });

    for (const r of rsvps) {
      if (r.userId !== userId) {
        this.notificationsService
          .createAndSend({
            recipientId: r.userId,
            senderId: userId,
            type: NotificationType.EVENT_CANCELLED,
            category: NotificationCategory.COMMUNITY,
            title: `Event Cancelled: ${event.title}`,
            body: dto.reason ? `Reason: ${dto.reason}` : `The organizer has cancelled "${event.title}".`,
            data: { eventId: id },
            deepLink: `/events/${id}`,
            deduplicationKey: `event_cancel:${id}:${r.userId}`,
          })
          .catch((err) => {
            this.logger.warn(`[EventsService] Failed to notify participant ${r.userId} of cancellation:`, err);
          });
      }
    }

    return this.getEventById(id, userId);
  }

  /**
   * Delete an event (Soft-delete alias for cancellation/removal).
   */
  async deleteEvent(id: string, userId: string): Promise<{ success: boolean; message: string }> {
    await this.cancelEvent(id, userId, { reason: 'Event deleted by organizer.' });
    await this.eventRepo.softDelete({ id });
    return { success: true, message: 'Event deleted successfully.' };
  }

  /**
   * RSVP to an event.
   */
  async rsvpEvent(
    eventId: string,
    userId: string,
    dto: RsvpEventDto,
  ): Promise<{ success: boolean; status: EventRsvpStatus; participantCount: number }> {
    await this.checkRateLimit(`events:rsvp:rate:${userId}`, this.rsvpRateLimitMax, this.rsvpRateLimitWindowSeconds);

    const event = await this.eventRepo.findOne({
      where: { id: eventId },
      relations: ['community'],
    });

    if (!event) {
      throw new NotFoundException('Event not found.');
    }

    if (event.status === EventStatus.CANCELLED) {
      throw new BadRequestException('Cannot RSVP to a cancelled event.');
    }

    if (event.endAt < new Date()) {
      throw new BadRequestException('Cannot RSVP to a past event.');
    }

    if (event.community && event.community.visibility === CommunityVisibility.PRIVATE) {
      const isMember = await this.isCommunityMember(event.community.id, userId);
      if (!isMember) {
        throw new ForbiddenException('Cannot RSVP to an event in a private community you have not joined.');
      }
    }

    const rsvpStatus = dto.status ?? EventRsvpStatus.GOING;

    let rsvp = await this.rsvpRepo.findOne({
      where: { eventId, userId },
    });

    if (rsvp) {
      if (rsvp.status !== rsvpStatus) {
        rsvp.status = rsvpStatus;
        await this.rsvpRepo.save(rsvp);
      }
    } else {
      rsvp = this.rsvpRepo.create({
        eventId,
        userId,
        status: rsvpStatus,
      });
      await this.rsvpRepo.save(rsvp);
    }

    // Recalculate participant count (users who are "going")
    const participantCount = await this.rsvpRepo.count({
      where: { eventId, status: EventRsvpStatus.GOING },
    });

    event.participantCount = participantCount;
    await this.eventRepo.save(event);

    // Notify organizer if someone else RSVP'd "going"
    if (userId !== event.creatorId && rsvpStatus === EventRsvpStatus.GOING) {
      const callerUser = await this.userRepo.findOne({ where: { id: userId } });
      const attendeeName = callerUser?.displayName || 'A neighbor';

      this.notificationsService
        .createAndSend({
          recipientId: event.creatorId,
          senderId: userId,
          type: NotificationType.EVENT_RSVP,
          category: NotificationCategory.COMMUNITY,
          title: `New RSVP for ${event.title}`,
          body: `${attendeeName} is attending your event.`,
          data: { eventId, attendeeId: userId },
          deepLink: `/events/${eventId}`,
          deduplicationKey: `event_rsvp:${eventId}:${userId}`,
        })
        .catch((err) => {
          this.logger.warn(`[EventsService] Failed to notify organizer ${event.creatorId} of RSVP:`, err);
        });
    }

    return {
      success: true,
      status: rsvpStatus,
      participantCount,
    };
  }

  /**
   * Cancel an RSVP.
   */
  async cancelRsvp(
    eventId: string,
    userId: string,
  ): Promise<{ success: boolean; participantCount: number }> {
    const event = await this.eventRepo.findOne({ where: { id: eventId } });
    if (!event) {
      throw new NotFoundException('Event not found.');
    }

    const rsvp = await this.rsvpRepo.findOne({
      where: { eventId, userId },
    });

    if (rsvp) {
      await this.rsvpRepo.remove(rsvp);
    }

    const participantCount = await this.rsvpRepo.count({
      where: { eventId, status: EventRsvpStatus.GOING },
    });

    event.participantCount = participantCount;
    await this.eventRepo.save(event);

    return { success: true, participantCount };
  }

  /**
   * List paginated participants for an event.
   */
  async getEventParticipants(
    eventId: string,
    currentUserId: string,
    limit: number = 20,
    cursor?: string,
  ): Promise<PaginatedParticipantsResponseDto> {
    const event = await this.eventRepo.findOne({
      where: { id: eventId },
      relations: ['community'],
    });

    if (!event) {
      throw new NotFoundException('Event not found.');
    }

    if (event.community && event.community.visibility === CommunityVisibility.PRIVATE) {
      const isMember = await this.isCommunityMember(event.community.id, currentUserId);
      if (!isMember) {
        throw new ForbiddenException('Cannot view participants for private community event.');
      }
    }

    const parsedLimit = Math.min(Math.max(Number(limit), 1), 50);

    const qb = this.rsvpRepo
      .createQueryBuilder('r')
      .leftJoinAndSelect('r.user', 'user')
      .where('r.eventId = :eventId', { eventId })
      .orderBy('r.createdAt', 'DESC')
      .take(parsedLimit + 1);

    if (cursor) {
      const cursorDate = new Date(cursor);
      if (!isNaN(cursorDate.getTime())) {
        qb.andWhere('r.createdAt < :cursorDate', { cursorDate });
      }
    }

    const rawItems = await qb.getMany();
    const hasMore = rawItems.length > parsedLimit;
    const items = hasMore ? rawItems.slice(0, parsedLimit) : rawItems;

    const participantDtos: EventParticipantDto[] = items.map((r) => ({
      id: r.id,
      userId: r.userId,
      user: {
        id: r.user?.id || r.userId,
        displayName: r.user?.displayName || 'Neighbor',
        avatarUrl: r.user?.avatarUrl ?? null,
        locality: r.user?.locality ?? null,
      },
      status: r.status,
      createdAt: r.createdAt.toISOString(),
    }));

    const nextCursor =
      hasMore && items.length > 0
        ? items[items.length - 1]!.createdAt.toISOString()
        : null;

    return { items: participantDtos, nextCursor, hasMore };
  }

  // ── Helper Methods ──────────────────────────────────────────────────────────

  private async isCommunityMember(communityId: string, userId: string): Promise<boolean> {
    const member = await this.communityMemberRepo.findOne({
      where: { communityId, userId, status: 'active' as any },
    });
    return !!member;
  }

  private async checkRateLimit(key: string, limit: number, windowSeconds: number): Promise<void> {
    try {
      const current = typeof this.redisService.incrementWithExpire === 'function'
        ? await this.redisService.incrementWithExpire(key, windowSeconds)
        : await this.redisService.incr(key);

      if (current > limit) {
        throw new HttpException(
          `Rate limit exceeded. Please wait before creating or mutating more events.`,
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    } catch (err: any) {
      if (err instanceof HttpException) throw err;
      this.logger.warn(`[EventsService] Redis rate limit check failed, allowing request: ${err.message}`);
    }
  }

  private formatEventResponse(
    event: Event,
    userRsvpStatus: EventRsvpStatus | null = null,
    distanceMeters: number | null = null,
    currentUserId?: string,
  ): EventResponseDto {
    return {
      id: event.id,
      creatorId: event.creatorId,
      creator: event.creator
        ? {
            id: event.creator.id,
            displayName: event.creator.displayName || 'Neighbor',
            avatarUrl: event.creator.avatarUrl ?? null,
            locality: event.creator.locality ?? null,
          }
        : undefined,
      communityId: event.communityId ?? null,
      community: event.community
        ? {
            id: event.community.id,
            name: event.community.name,
            slug: event.community.slug,
            visibility: event.community.visibility,
          }
        : null,
      title: event.title,
      description: event.description,
      category: event.category,
      status: event.status,
      startAt: event.startAt.toISOString(),
      endAt: event.endAt.toISOString(),
      timezone: event.timezone,
      venue: event.venue,
      address: event.address,
      locality: event.locality ?? null,
      city: event.city ?? null,
      state: event.state ?? null,
      countryCode: event.countryCode,
      distanceMeters,
      coverImageUrl: event.coverImageUrl ?? null,
      participantCount: event.participantCount,
      userRsvpStatus,
      isOrganizer: currentUserId ? event.creatorId === currentUserId : false,
      cancelledAt: event.cancelledAt ? event.cancelledAt.toISOString() : null,
      cancellationReason: event.cancellationReason ?? null,
      createdAt: event.createdAt.toISOString(),
      updatedAt: event.updatedAt.toISOString(),
    };
  }
}

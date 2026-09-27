import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  HttpException,
} from '@nestjs/common';
import { EventsService } from '../../src/modules/events/events.service.js';
import { EventCategory, EventStatus } from '../../src/modules/events/entities/event.entity.js';
import { EventRsvpStatus } from '../../src/modules/events/entities/event-rsvp.entity.js';
import { CommunityVisibility } from '../../src/modules/communities/entities/community.entity.js';
import { CommunityRole, CommunityMemberStatus } from '../../src/modules/communities/entities/community-member.entity.js';

describe('EventsService', () => {
  let service: EventsService;
  let mockEventRepo: any;
  let mockRsvpRepo: any;
  let mockCommunityRepo: any;
  let mockMemberRepo: any;
  let mockUserRepo: any;
  let mockRedisService: any;
  let mockNotificationsService: any;

  const userOrganizer = {
    id: '11111111-1111-1111-1111-111111111111',
    displayName: 'Organizer User',
    avatarUrl: 'https://example.com/org.jpg',
    locality: 'Koramangala',
    city: 'Bengaluru',
  };

  const userAttendee = {
    id: '22222222-2222-2222-2222-222222222222',
    displayName: 'Attendee User',
    avatarUrl: 'https://example.com/att.jpg',
    locality: 'Koramangala',
    city: 'Bengaluru',
  };

  const userStranger = {
    id: '33333333-3333-3333-3333-333333333333',
    displayName: 'Stranger User',
    avatarUrl: null,
    locality: 'Indiranagar',
    city: 'Bengaluru',
  };

  const futureDateStart = new Date(Date.now() + 86400000); // +1 day
  const futureDateEnd = new Date(Date.now() + 90000000); // +25 hours

  const mockPublicCommunity = {
    id: 'comm-public-1',
    name: 'Koramangala Techies',
    slug: 'koramangala-techies',
    visibility: CommunityVisibility.PUBLIC,
  };

  const mockPrivateCommunity = {
    id: 'comm-private-1',
    name: 'Secret Society',
    slug: 'secret-society',
    visibility: CommunityVisibility.PRIVATE,
  };

  const mockActiveEvent = {
    id: 'event-uuid-1',
    creatorId: userOrganizer.id,
    communityId: null,
    title: 'Indiranagar Weekend Run',
    description: '5k morning run starting from 12th Main park.',
    category: EventCategory.SPORTS,
    status: EventStatus.ACTIVE,
    startAt: futureDateStart,
    endAt: futureDateEnd,
    timezone: 'Asia/Kolkata',
    venue: '12th Main Park Gate',
    address: '12th Main Rd, HAL 2nd Stage, Indiranagar',
    locality: 'Indiranagar',
    city: 'Bengaluru',
    state: 'Karnataka',
    countryCode: 'IN',
    location: { type: 'Point', coordinates: [77.6412, 12.9716] },
    coverImageUrl: 'https://example.com/run.jpg',
    participantCount: 1,
    cancelledAt: null,
    cancellationReason: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
    creator: userOrganizer,
    community: null,
  };
  let currentEventState: any;

  beforeEach(() => {
    currentEventState = { ...mockActiveEvent };

    const createEventQb = (eventResult?: any) => {
      const result = eventResult !== undefined ? eventResult : currentEventState;
      return {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        addOrderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        skip: vi.fn().mockReturnThis(),
        getOne: vi.fn().mockResolvedValue(result),
        getMany: vi.fn().mockResolvedValue(result ? [result] : []),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: result ? [result] : [],
          raw: [{}],
        }),
      };
    };

    mockEventRepo = {
      create: vi.fn((data: any) => {
        currentEventState = {
          ...mockActiveEvent,
          ...data,
          id: 'event-uuid-1',
          creator: userOrganizer,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
        return currentEventState;
      }),
      save: vi.fn(async (event: any) => {
        currentEventState = {
          ...currentEventState,
          ...event,
          id: event.id || 'event-uuid-1',
          updatedAt: new Date(),
        };
        return currentEventState;
      }),
      findOne: vi.fn(async () => currentEventState),
      find: vi.fn().mockResolvedValue([mockActiveEvent]),
      createQueryBuilder: vi.fn(() => createEventQb()),
    };

    mockRsvpRepo = {
      create: vi.fn((data: any) => ({
        ...data,
        id: 'rsvp-uuid-1',
        createdAt: new Date(),
        updatedAt: new Date(),
      })),
      save: vi.fn(async (rsvp: any) => ({ ...rsvp, id: rsvp.id || 'rsvp-uuid-1' })),
      findOne: vi.fn().mockResolvedValue(null),
      find: vi.fn().mockResolvedValue([]),
      count: vi.fn().mockResolvedValue(1),
      remove: vi.fn().mockResolvedValue(undefined),
      createQueryBuilder: vi.fn(),
    };

    mockCommunityRepo = {
      findOne: vi.fn().mockResolvedValue(null),
    };

    mockMemberRepo = {
      findOne: vi.fn().mockResolvedValue(null),
    };

    mockUserRepo = {
      findOne: vi.fn(async ({ where }: any) => {
        if (where?.id === userOrganizer.id) return userOrganizer;
        if (where?.id === userAttendee.id) return userAttendee;
        return userStranger;
      }),
    };

    mockRedisService = {
      incrementWithExpire: vi.fn().mockResolvedValue(1),
      get: vi.fn().mockResolvedValue(null),
      set: vi.fn().mockResolvedValue(undefined),
      del: vi.fn().mockResolvedValue(1),
    };

    mockNotificationsService = {
      createAndSend: vi.fn().mockResolvedValue({ id: 'notif-1' }),
      createNotification: vi.fn().mockResolvedValue({ id: 'notif-1' }),
    };

    service = new EventsService(
      mockEventRepo,
      mockRsvpRepo,
      mockCommunityRepo,
      mockMemberRepo,
      mockUserRepo,
      mockRedisService,
      mockNotificationsService,
    );
  });

  describe('createEvent', () => {
    it('creates an event successfully and automatically marks organizer as GOING', async () => {
      const dto = {
        title: 'Tech Meetup 2026',
        description: 'Discussing the future of hyperlocal systems.',
        category: EventCategory.WORKSHOP,
        startAt: futureDateStart.toISOString(),
        endAt: futureDateEnd.toISOString(),
        venue: '91springboard Koramangala',
        address: '80 Feet Rd, Koramangala',
        locality: 'Koramangala',
        city: 'Bengaluru',
        latitude: 12.9352,
        longitude: 77.6245,
      };

      const result = await service.createEvent(userOrganizer.id, dto as any);

      expect(mockEventRepo.create).toHaveBeenCalled();
      expect(mockEventRepo.save).toHaveBeenCalled();
      expect(mockRsvpRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: userOrganizer.id,
          status: EventRsvpStatus.GOING,
        }),
      );
      expect(result.title).toBe(dto.title);
      expect(result.participantCount).toBe(1);
    });

    it('throws BadRequestException if end date is before start date', async () => {
      const dto = {
        title: 'Time Travel Event',
        description: 'Ends before it begins.',
        category: EventCategory.WORKSHOP,
        startAt: futureDateEnd.toISOString(),
        endAt: futureDateStart.toISOString(), // end < start
        venue: 'Somewhere',
        address: 'Nowhere',
      };

      await expect(service.createEvent(userOrganizer.id, dto as any)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('throws ForbiddenException if creating an event in a private community without membership', async () => {
      mockCommunityRepo.findOne.mockResolvedValue(mockPrivateCommunity);
      mockMemberRepo.findOne.mockResolvedValue(null); // not a member

      const dto = {
        title: 'Secret Meeting',
        description: 'Members only.',
        category: EventCategory.SOCIAL,
        startAt: futureDateStart.toISOString(),
        endAt: futureDateEnd.toISOString(),
        venue: 'Secret Hideout',
        address: 'Unknown',
        communityId: mockPrivateCommunity.id,
      };

      await expect(service.createEvent(userStranger.id, dto as any)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('enforces rate limit for event creation', async () => {
      mockRedisService.incrementWithExpire.mockResolvedValue(11); // Max is 10

      const dto = {
        title: 'Spam Event',
        description: 'Rate limit testing.',
        category: EventCategory.OTHER,
        startAt: futureDateStart.toISOString(),
        endAt: futureDateEnd.toISOString(),
        venue: 'Anywhere',
        address: 'Anywhere',
      };

      await expect(service.createEvent(userOrganizer.id, dto as any)).rejects.toThrow(
        HttpException,
      );
    });
  });

  describe('updateEvent', () => {
    it('allows organizer to update event details', async () => {
      mockEventRepo.findOne.mockResolvedValue({ ...mockActiveEvent });

      const dto = {
        title: 'Updated Event Title',
        description: 'Updated description.',
      };

      const result = await service.updateEvent(mockActiveEvent.id, userOrganizer.id, dto);

      expect(mockEventRepo.save).toHaveBeenCalled();
      expect(result.title).toBe('Updated Event Title');
    });

    it('rejects update if user is not the organizer (ForbiddenException)', async () => {
      mockEventRepo.findOne.mockResolvedValue({ ...mockActiveEvent });

      await expect(
        service.updateEvent(mockActiveEvent.id, userStranger.id, { title: 'Hacked Title' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects update if event is cancelled', async () => {
      mockEventRepo.findOne.mockResolvedValue({
        ...mockActiveEvent,
        status: EventStatus.CANCELLED,
      });

      await expect(
        service.updateEvent(mockActiveEvent.id, userOrganizer.id, { title: 'New Title' }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('cancelEvent', () => {
    it('allows organizer to cancel event and notifies participants', async () => {
      mockEventRepo.findOne.mockResolvedValue({ ...mockActiveEvent });
      mockRsvpRepo.find.mockResolvedValue([
        { userId: userAttendee.id, status: EventRsvpStatus.GOING },
      ]);

      const result = await service.cancelEvent(mockActiveEvent.id, userOrganizer.id, {
        reason: 'Heavy rain predicted.',
      });

      expect(mockEventRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          status: EventStatus.CANCELLED,
          cancellationReason: 'Heavy rain predicted.',
        }),
      );
      expect(mockNotificationsService.createAndSend).toHaveBeenCalled();
      expect(result.status).toBe(EventStatus.CANCELLED);
    });

    it('rejects cancellation from non-organizer (ForbiddenException)', async () => {
      mockEventRepo.findOne.mockResolvedValue({ ...mockActiveEvent });

      await expect(
        service.cancelEvent(mockActiveEvent.id, userStranger.id, { reason: 'Sneaky cancel' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects cancellation if already cancelled', async () => {
      currentEventState = {
        ...mockActiveEvent,
        status: EventStatus.CANCELLED,
      };

      await expect(
        service.cancelEvent(mockActiveEvent.id, userOrganizer.id, { reason: 'Again' }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('RSVP workflow', () => {
    it('allows user to RSVP to an active event and notifies organizer', async () => {
      mockEventRepo.findOne.mockResolvedValue({ ...mockActiveEvent, participantCount: 1 });
      mockRsvpRepo.findOne.mockResolvedValue(null); // not yet RSVPed
      mockRsvpRepo.count.mockResolvedValue(2);

      const result = await service.rsvpEvent(mockActiveEvent.id, userAttendee.id, {
        status: EventRsvpStatus.GOING,
      });

      expect(result.success).toBe(true);
      expect(result.status).toBe(EventRsvpStatus.GOING);
      expect(result.participantCount).toBe(2);
      expect(mockNotificationsService.createAndSend).toHaveBeenCalled();
    });

    it('rejects RSVP to a cancelled event', async () => {
      currentEventState = {
        ...mockActiveEvent,
        status: EventStatus.CANCELLED,
      };

      await expect(
        service.rsvpEvent(mockActiveEvent.id, userAttendee.id, {
          status: EventRsvpStatus.GOING,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('allows attendee to cancel their RSVP and updates participant count', async () => {
      mockEventRepo.findOne.mockResolvedValue({ ...mockActiveEvent, participantCount: 2 });
      mockRsvpRepo.findOne.mockResolvedValue({
        id: 'rsvp-1',
        eventId: mockActiveEvent.id,
        userId: userAttendee.id,
        status: EventRsvpStatus.GOING,
      });
      mockRsvpRepo.count.mockResolvedValue(1);

      const result = await service.cancelRsvp(mockActiveEvent.id, userAttendee.id);

      expect(result.success).toBe(true);
      expect(result.participantCount).toBe(1);
      expect(mockRsvpRepo.remove).toHaveBeenCalled();
    });
  });

  describe('Community & Privacy Visibility', () => {
    it('prevents non-members from viewing private community events', async () => {
      const privateEvent = { ...mockActiveEvent, community: mockPrivateCommunity };
      currentEventState = privateEvent;
      mockEventRepo.createQueryBuilder.mockReturnValue({
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [privateEvent],
          raw: [{}],
        }),
      });
      mockMemberRepo.findOne.mockResolvedValue(null); // not a member

      await expect(
        service.getEventById(mockActiveEvent.id, userStranger.id),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows members to view private community events', async () => {
      const privateEvent = { ...mockActiveEvent, community: mockPrivateCommunity };
      currentEventState = privateEvent;
      mockEventRepo.createQueryBuilder.mockReturnValue({
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [privateEvent],
          raw: [{}],
        }),
      });
      mockMemberRepo.findOne.mockResolvedValue({
        communityId: mockPrivateCommunity.id,
        userId: userAttendee.id,
        status: CommunityMemberStatus.ACTIVE,
      });

      const event = await service.getEventById(mockActiveEvent.id, userAttendee.id);
      expect(event.id).toBe(mockActiveEvent.id);
    });
  });

  describe('Discovery / Query Logic', () => {
    it('queries upcoming events excluding cancelled ones by default', async () => {
      const qbMock: any = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        addOrderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([mockActiveEvent]),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [mockActiveEvent],
          raw: [],
        }),
      };
      mockEventRepo.createQueryBuilder.mockReturnValue(qbMock);

      const res = await service.getEvents(userAttendee.id, {
        locality: 'Indiranagar',
        category: EventCategory.SPORTS,
        limit: 10,
      });

      expect(qbMock.where).toHaveBeenCalledWith('e.deletedAt IS NULL');
      expect(qbMock.andWhere).toHaveBeenCalledWith(
        'e.status = :status',
        expect.objectContaining({ status: EventStatus.ACTIVE }),
      );
      expect(res.items.length).toBe(1);
    });
  });
});

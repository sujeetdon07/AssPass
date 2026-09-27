import { describe, it, expect, beforeEach, vi } from 'vitest';
import { EventsController } from '../../src/modules/events/events.controller.js';
import { EventsService } from '../../src/modules/events/events.service.js';
import { CurrentUserPayload } from '../../src/modules/auth/decorators/current-user.decorator.js';
import { EventCategory, EventStatus } from '../../src/modules/events/entities/event.entity.js';
import { EventRsvpStatus } from '../../src/modules/events/entities/event-rsvp.entity.js';

describe('EventsController', () => {
  let controller: EventsController;
  let mockService: any;

  const mockUser: CurrentUserPayload = {
    userId: '11111111-1111-1111-1111-111111111111',
    sessionId: 'session-123',
    phoneNumber: '+919876543210',
    onboarding: true,
  };

  const sampleEvent = {
    id: 'event-123',
    title: 'Koramangala Clean Up Drive',
    description: 'Community volunteer event to clean the neighborhood park.',
    category: EventCategory.VOLUNTEERING,
    status: EventStatus.ACTIVE,
    startAt: new Date(Date.now() + 86400000).toISOString(),
    endAt: new Date(Date.now() + 90000000).toISOString(),
    timezone: 'Asia/Kolkata',
    venue: 'BBMP Park 4th Block',
    address: '4th Block, Koramangala',
    locality: 'Koramangala',
    city: 'Bengaluru',
    participantCount: 5,
    myRsvpStatus: EventRsvpStatus.GOING,
    isOrganizer: true,
  };

  beforeEach(() => {
    mockService = {
      createEvent: vi.fn().mockResolvedValue(sampleEvent),
      getEvents: vi.fn().mockResolvedValue({ items: [sampleEvent], nextCursor: null, hasMore: false }),
      getEventById: vi.fn().mockResolvedValue(sampleEvent),
      updateEvent: vi.fn().mockResolvedValue({ ...sampleEvent, title: 'Updated Clean Up Drive' }),
      cancelEvent: vi.fn().mockResolvedValue({ ...sampleEvent, status: EventStatus.CANCELLED }),
      rsvpEvent: vi.fn().mockResolvedValue({ success: true, status: EventRsvpStatus.GOING, participantCount: 6 }),
      cancelRsvp: vi.fn().mockResolvedValue({ success: true, participantCount: 4 }),
      getEventParticipants: vi.fn().mockResolvedValue({ participants: [], nextCursor: null, hasMore: false }),
    };

    controller = new EventsController(mockService as EventsService);
  });

  it('delegates createEvent to EventsService', async () => {
    const dto = {
      title: 'Koramangala Clean Up Drive',
      description: 'Community volunteer event to clean the neighborhood park.',
      category: EventCategory.VOLUNTEERING,
      startAt: new Date().toISOString(),
      endAt: new Date().toISOString(),
      venue: 'BBMP Park',
      address: '4th Block',
    };

    const res = await controller.createEvent(mockUser, dto as any);
    expect(mockService.createEvent).toHaveBeenCalledWith(mockUser.userId, dto);
    expect(res.id).toBe('event-123');
  });

  it('delegates getEvents to EventsService', async () => {
    const query = { locality: 'Koramangala', limit: 10 };
    const res = await controller.getEvents(mockUser, query as any);
    expect(mockService.getEvents).toHaveBeenCalledWith(mockUser.userId, query);
    expect(res.items.length).toBe(1);
  });

  it('delegates getEventById to EventsService', async () => {
    const res = await controller.getEventById('event-123', mockUser);
    expect(mockService.getEventById).toHaveBeenCalledWith('event-123', mockUser.userId);
    expect(res.id).toBe('event-123');
  });

  it('delegates updateEvent to EventsService', async () => {
    const dto = { title: 'Updated Clean Up Drive' };
    const res = await controller.updateEvent('event-123', mockUser, dto as any);
    expect(mockService.updateEvent).toHaveBeenCalledWith('event-123', mockUser.userId, dto);
    expect(res.title).toBe('Updated Clean Up Drive');
  });

  it('delegates cancelEvent to EventsService', async () => {
    const dto = { reason: 'Raining heavily' };
    const res = await controller.cancelEvent('event-123', mockUser, dto as any);
    expect(mockService.cancelEvent).toHaveBeenCalledWith('event-123', mockUser.userId, dto);
    expect(res.status).toBe(EventStatus.CANCELLED);
  });

  it('delegates rsvpEvent to EventsService', async () => {
    const dto = { status: EventRsvpStatus.GOING };
    const res = await controller.rsvpEvent('event-123', mockUser, dto as any);
    expect(mockService.rsvpEvent).toHaveBeenCalledWith('event-123', mockUser.userId, dto);
    expect(res.success).toBe(true);
    expect(res.participantCount).toBe(6);
  });

  it('delegates cancelRsvp to EventsService', async () => {
    const res = await controller.cancelRsvp('event-123', mockUser);
    expect(mockService.cancelRsvp).toHaveBeenCalledWith('event-123', mockUser.userId);
    expect(res.success).toBe(true);
    expect(res.participantCount).toBe(4);
  });

  it('delegates getEventParticipants to EventsService', async () => {
    const res = await controller.getEventParticipants('event-123', mockUser, 20);
    expect(mockService.getEventParticipants).toHaveBeenCalledWith('event-123', mockUser.userId, 20, undefined);
    expect(res.participants).toBeDefined();
  });
});

import { EventCategory, EventStatus } from '../entities/event.entity.js';
import { EventRsvpStatus } from '../entities/event-rsvp.entity.js';

export interface EventCreatorProfile {
  id: string;
  displayName: string;
  avatarUrl?: string | null;
  locality?: string | null;
}

export interface EventCommunitySummary {
  id: string;
  name: string;
  slug: string;
  visibility: string;
}

export interface EventResponseDto {
  id: string;
  creatorId: string;
  creator?: EventCreatorProfile;
  communityId?: string | null;
  community?: EventCommunitySummary | null;
  title: string;
  description: string;
  category: EventCategory;
  status: EventStatus;
  startAt: string;
  endAt: string;
  timezone: string;
  venue: string;
  address: string;
  locality?: string | null;
  city?: string | null;
  state?: string | null;
  countryCode: string;
  latitude?: number | null;
  longitude?: number | null;
  distanceMeters?: number | null;
  coverImageUrl?: string | null;
  participantCount: number;
  userRsvpStatus?: EventRsvpStatus | null;
  isOrganizer?: boolean;
  cancelledAt?: string | null;
  cancellationReason?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PaginatedEventsResponseDto {
  items: EventResponseDto[];
  nextCursor: string | null;
  hasMore: boolean;
}

export interface EventParticipantDto {
  id: string;
  userId: string;
  user: EventCreatorProfile;
  status: EventRsvpStatus;
  createdAt: string;
}

export interface PaginatedParticipantsResponseDto {
  items: EventParticipantDto[];
  nextCursor: string | null;
  hasMore: boolean;
}

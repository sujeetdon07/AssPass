import 'event_category.dart';
import 'event_rsvp_status.dart';

/// Organizer profile projection attached to an event.
class EventOrganizerEntity {
  const EventOrganizerEntity({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.locality,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? locality;
}

/// Community projection attached to an event.
class EventCommunityEntity {
  const EventCommunityEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.visibility,
  });

  final String id;
  final String name;
  final String slug;
  final String visibility;

  bool get isPrivate => visibility.toLowerCase() == 'private';
}

/// Pure domain entity representing an Event in Aaspaas.
class EventEntity {
  const EventEntity({
    required this.id,
    required this.creatorId,
    this.creator,
    this.communityId,
    this.community,
    required this.title,
    required this.description,
    required this.category,
    this.status = 'active',
    required this.startAt,
    required this.endAt,
    this.timezone = 'Asia/Kolkata',
    required this.venue,
    required this.address,
    this.locality,
    this.city,
    this.state,
    this.countryCode = 'IN',
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.coverImageUrl,
    this.participantCount = 0,
    this.userRsvpStatus,
    this.isOrganizer = false,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String creatorId;
  final EventOrganizerEntity? creator;
  final String? communityId;
  final EventCommunityEntity? community;
  final String title;
  final String description;
  final EventCategory category;
  final String status;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;
  final String venue;
  final String address;
  final String? locality;
  final String? city;
  final String? state;
  final String countryCode;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;
  final String? coverImageUrl;
  final int participantCount;
  final EventRsvpStatus? userRsvpStatus;
  final bool isOrganizer;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isCompleted => status.toLowerCase() == 'completed' || endAt.isBefore(DateTime.now());
  bool get isUpcoming => !isCancelled && !isCompleted;
  bool get isGoing => userRsvpStatus == EventRsvpStatus.going;
  bool get isInterested => userRsvpStatus == EventRsvpStatus.interested;

  EventEntity copyWith({
    String? id,
    String? creatorId,
    EventOrganizerEntity? creator,
    String? communityId,
    EventCommunityEntity? community,
    String? title,
    String? description,
    EventCategory? category,
    String? status,
    DateTime? startAt,
    DateTime? endAt,
    String? timezone,
    String? venue,
    String? address,
    String? locality,
    String? city,
    String? state,
    String? countryCode,
    double? latitude,
    double? longitude,
    double? distanceMeters,
    String? coverImageUrl,
    int? participantCount,
    EventRsvpStatus? userRsvpStatus,
    bool clearUserRsvp = false,
    bool? isOrganizer,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventEntity(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creator: creator ?? this.creator,
      communityId: communityId ?? this.communityId,
      community: community ?? this.community,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      timezone: timezone ?? this.timezone,
      venue: venue ?? this.venue,
      address: address ?? this.address,
      locality: locality ?? this.locality,
      city: city ?? this.city,
      state: state ?? this.state,
      countryCode: countryCode ?? this.countryCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      participantCount: participantCount ?? this.participantCount,
      userRsvpStatus: clearUserRsvp ? null : (userRsvpStatus ?? this.userRsvpStatus),
      isOrganizer: isOrganizer ?? this.isOrganizer,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

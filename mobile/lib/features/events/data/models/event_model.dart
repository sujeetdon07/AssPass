import '../../domain/entities/event_category.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/entities/event_rsvp_status.dart';

/// Data model representing an Event DTO from the REST API.
class EventModel {
  const EventModel({
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
  final Map<String, dynamic>? creator;
  final String? communityId;
  final Map<String, dynamic>? community;
  final String title;
  final String description;
  final String category;
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
  final String? userRsvpStatus;
  final bool isOrganizer;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is String) {
        return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      }
      return fallback ?? DateTime.now();
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return EventModel(
      id: json['id'] as String? ?? '',
      creatorId: json['creatorId'] as String? ?? '',
      creator: json['creator'] as Map<String, dynamic>?,
      communityId: json['communityId'] as String?,
      community: json['community'] as Map<String, dynamic>?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      status: json['status'] as String? ?? 'active',
      startAt: parseDate(json['startAt']),
      endAt: parseDate(json['endAt']),
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
      venue: json['venue'] as String? ?? '',
      address: json['address'] as String? ?? '',
      locality: json['locality'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      countryCode: json['countryCode'] as String? ?? 'IN',
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      distanceMeters: parseDouble(json['distanceMeters']),
      coverImageUrl: json['coverImageUrl'] as String?,
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      userRsvpStatus: json['userRsvpStatus'] as String?,
      isOrganizer: json['isOrganizer'] as bool? ?? false,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'] as String)
          : null,
      cancellationReason: json['cancellationReason'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  EventEntity toEntity() {
    EventOrganizerEntity? org;
    if (creator != null) {
      org = EventOrganizerEntity(
        id: creator!['id'] as String? ?? creatorId,
        displayName: creator!['displayName'] as String? ?? 'Organizer',
        avatarUrl: creator!['avatarUrl'] as String?,
        locality: creator!['locality'] as String?,
      );
    }

    EventCommunityEntity? comm;
    if (community != null) {
      comm = EventCommunityEntity(
        id: community!['id'] as String? ?? '',
        name: community!['name'] as String? ?? '',
        slug: community!['slug'] as String? ?? '',
        visibility: community!['visibility'] as String? ?? 'public',
      );
    }

    return EventEntity(
      id: id,
      creatorId: creatorId,
      creator: org,
      communityId: communityId,
      community: comm,
      title: title,
      description: description,
      category: EventCategory.fromString(category),
      status: status,
      startAt: startAt,
      endAt: endAt,
      timezone: timezone,
      venue: venue,
      address: address,
      locality: locality,
      city: city,
      state: state,
      countryCode: countryCode,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters,
      coverImageUrl: coverImageUrl,
      participantCount: participantCount,
      userRsvpStatus: EventRsvpStatus.fromString(userRsvpStatus),
      isOrganizer: isOrganizer,
      cancelledAt: cancelledAt,
      cancellationReason: cancellationReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

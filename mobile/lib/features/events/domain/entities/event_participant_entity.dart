import 'event_rsvp_status.dart';

/// Participant record entity in an Event.
class EventParticipantEntity {
  const EventParticipantEntity({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.locality,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? locality;
  final EventRsvpStatus status;
  final DateTime createdAt;
}

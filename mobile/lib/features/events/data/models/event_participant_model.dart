import '../../domain/entities/event_participant_entity.dart';
import '../../domain/entities/event_rsvp_status.dart';

/// Data model representing an Event Participant DTO from the REST API.
class EventParticipantModel {
  const EventParticipantModel({
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
  final String status;
  final DateTime createdAt;

  factory EventParticipantModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return EventParticipantModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      displayName: user?['displayName'] as String? ??
          json['displayName'] as String? ??
          'Participant',
      avatarUrl: user?['avatarUrl'] as String? ?? json['avatarUrl'] as String?,
      locality: user?['locality'] as String? ?? json['locality'] as String?,
      status: json['status'] as String? ?? 'going',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  EventParticipantEntity toEntity() {
    return EventParticipantEntity(
      id: id,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      locality: locality,
      status: EventRsvpStatus.fromString(status) ?? EventRsvpStatus.going,
      createdAt: createdAt,
    );
  }
}

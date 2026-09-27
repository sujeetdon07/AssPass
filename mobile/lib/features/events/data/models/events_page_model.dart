import '../../domain/entities/event_entity.dart';
import 'event_model.dart';

/// Paginated result of events returned from the API.
class EventsPageModel {
  const EventsPageModel({
    required this.events,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<EventEntity> events;
  final String? nextCursor;
  final bool hasMore;

  factory EventsPageModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['items'] as List<dynamic>? ?? [];
    final events = rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => EventModel.fromJson(e).toEntity())
        .toList();

    return EventsPageModel(
      events: events,
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

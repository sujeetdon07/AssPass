import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/entities/event_participant_entity.dart';
import '../../domain/entities/event_rsvp_status.dart';
import '../models/event_model.dart';
import '../models/event_participant_model.dart';
import '../models/events_page_model.dart';

/// Provider for [EventsRepository].
final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return EventsRepository(dio);
});

/// Client repository handling all Events API interactions.
class EventsRepository {
  const EventsRepository(this._dio);

  final Dio _dio;

  /// Fetch paginated list of events with hyperlocal filters.
  Future<EventsPageModel> getEvents({
    String? cursor,
    int limit = 20,
    String? category,
    String? locality,
    String? city,
    String? communityId,
    String timeframe = 'upcoming',
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        if (category != null && category.isNotEmpty) 'category': category,
        if (locality != null && locality.isNotEmpty) 'locality': locality,
        if (city != null && city.isNotEmpty) 'city': city,
        if (communityId != null && communityId.isNotEmpty) 'communityId': communityId,
        'timeframe': timeframe,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radiusKm != null) 'radiusKm': radiusKm,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
    return EventsPageModel.fromJson(data);
  }

  /// Retrieve single event details by ID.
  Future<EventEntity> getEventById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/events/$id');
    final data = response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
    return EventModel.fromJson(data).toEntity();
  }

  /// Create a new local community event.
  Future<EventEntity> createEvent({
    required String title,
    required String description,
    required String category,
    required String startAt,
    required String endAt,
    required String venue,
    required String address,
    String? locality,
    String? city,
    String? state,
    String? communityId,
    double? latitude,
    double? longitude,
    String? coverImageUrl,
    String timezone = 'Asia/Kolkata',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events',
      data: {
        'title': title,
        'description': description,
        'category': category,
        'startAt': startAt,
        'endAt': endAt,
        'venue': venue,
        'address': address,
        if (locality != null && locality.isNotEmpty) 'locality': locality,
        if (city != null && city.isNotEmpty) 'city': city,
        if (state != null && state.isNotEmpty) 'state': state,
        if (communityId != null && communityId.isNotEmpty) 'communityId': communityId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (coverImageUrl != null && coverImageUrl.isNotEmpty)
          'coverImageUrl': coverImageUrl,
        'timezone': timezone,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
    return EventModel.fromJson(data).toEntity();
  }

  /// Update an existing event (organizer only).
  Future<EventEntity> updateEvent(
    String id, {
    String? title,
    String? description,
    String? category,
    String? startAt,
    String? endAt,
    String? venue,
    String? address,
    String? locality,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    String? coverImageUrl,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/events/$id',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (startAt != null) 'startAt': startAt,
        if (endAt != null) 'endAt': endAt,
        if (venue != null) 'venue': venue,
        if (address != null) 'address': address,
        if (locality != null) 'locality': locality,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
    return EventModel.fromJson(data).toEntity();
  }

  /// Cancel an active event (organizer only).
  Future<EventEntity> cancelEvent(String id, {String? reason}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/$id/cancel',
      data: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
    return EventModel.fromJson(data).toEntity();
  }

  /// RSVP to an event.
  Future<Map<String, dynamic>> rsvpEvent(
    String id, {
    EventRsvpStatus status = EventRsvpStatus.going,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/$id/rsvp',
      data: {'status': status.value},
    );

    return response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
  }

  /// Cancel user's RSVP.
  Future<Map<String, dynamic>> cancelRsvp(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/events/$id/rsvp',
    );

    return response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
  }

  /// List participants for an event.
  Future<List<EventParticipantEntity>> getParticipants(
    String id, {
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/$id/participants',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
    final rawList = data['participants'] as List<dynamic>? ?? [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map((p) => EventParticipantModel.fromJson(p).toEntity())
        .toList();
  }

  /// Report an event through the centralized Trust & Safety reporting system.
  Future<void> reportEvent(
    String eventId, {
    required String reason,
    String? details,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/safety/reports',
      data: {
        'targetType': 'event',
        'targetId': eventId,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }
}

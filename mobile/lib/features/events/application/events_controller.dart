import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/events_repository.dart';
import '../domain/entities/event_category.dart';
import '../domain/entities/event_entity.dart';
import '../domain/entities/event_rsvp_status.dart';
import 'events_state.dart';

/// Provider for [EventsController].
final eventsControllerProvider =
    StateNotifierProvider<EventsController, EventsState>((ref) {
  final repository = ref.watch(eventsRepositoryProvider);
  return EventsController(repository);
});

/// StateNotifier controlling event listing, category filtering, search, and pagination.
class EventsController extends StateNotifier<EventsState> {
  EventsController(this._repository) : super(const EventsState()) {
    loadEvents();
  }

  final EventsRepository _repository;

  /// Load or refresh events list.
  Future<void> loadEvents({bool isRefresh = false}) async {
    if (state.isLoading || state.isRefreshing) return;

    state = state.copyWith(
      status: isRefresh ? EventsStatus.refreshing : EventsStatus.loading,
      errorMessage: null,
    );

    try {
      final page = await _repository.getEvents(
        category: state.selectedCategory?.value,
        timeframe: state.selectedTimeframe,
        locality: state.localityFilter,
        communityId: state.communityFilter,
      );

      debugPrint(
        '[EventsController] loaded: ${page.events.length} events, hasMore=${page.hasMore}',
      );

      state = state.copyWith(
        status: EventsStatus.loaded,
        events: page.events,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e, st) {
      debugPrint('[EventsController] loadEvents error: $e\n$st');
      state = state.copyWith(
        status: EventsStatus.error,
        errorMessage: 'Unable to load events. Tap retry.',
      );
    }
  }

  /// Load more events using cursor pagination.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) return;

    state = state.copyWith(status: EventsStatus.loadingMore);

    try {
      final page = await _repository.getEvents(
        cursor: state.nextCursor,
        category: state.selectedCategory?.value,
        timeframe: state.selectedTimeframe,
        locality: state.localityFilter,
        communityId: state.communityFilter,
      );

      final combined = [...state.events, ...page.events];
      state = state.copyWith(
        status: EventsStatus.loaded,
        events: combined,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e, st) {
      debugPrint('[EventsController] loadMore error: $e\n$st');
      state = state.copyWith(status: EventsStatus.loaded);
    }
  }

  /// Select category filter and reload.
  void setCategory(EventCategory? category) {
    if (state.selectedCategory == category) return;
    state = state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
      nextCursor: null,
    );
    loadEvents();
  }

  /// Select timeframe filter ('upcoming', 'weekend', 'past', 'all') and reload.
  void setTimeframe(String timeframe) {
    if (state.selectedTimeframe == timeframe) return;
    state = state.copyWith(
      selectedTimeframe: timeframe,
      nextCursor: null,
    );
    loadEvents();
  }

  /// Set locality filter and reload.
  void setLocality(String? locality) {
    state = state.copyWith(
      localityFilter: locality,
      clearLocality: locality == null,
      nextCursor: null,
    );
    loadEvents();
  }

  /// Set community scope filter and reload.
  void setCommunity(String? communityId) {
    state = state.copyWith(
      communityFilter: communityId,
      clearCommunity: communityId == null,
      nextCursor: null,
    );
    loadEvents();
  }

  /// Fast optimistic RSVP update across the list.
  Future<void> rsvpEvent(String eventId, EventRsvpStatus status) async {
    final originalIndex = state.events.indexWhere((e) => e.id == eventId);
    if (originalIndex == -1) return;

    final original = state.events[originalIndex];
    final wasGoing = original.userRsvpStatus == EventRsvpStatus.going;
    final isNowGoing = status == EventRsvpStatus.going;
    final countDelta = isNowGoing ? (wasGoing ? 0 : 1) : (wasGoing ? -1 : 0);

    final updated = original.copyWith(
      userRsvpStatus: status,
      participantCount: (original.participantCount + countDelta).clamp(0, 999999),
    );

    final updatedList = List<EventEntity>.from(state.events);
    updatedList[originalIndex] = updated;
    state = state.copyWith(events: updatedList);

    try {
      final res = await _repository.rsvpEvent(eventId, status: status);
      final finalCount = (res['participantCount'] as num?)?.toInt() ?? updated.participantCount;
      if (finalCount != updated.participantCount) {
        final syncedList = List<EventEntity>.from(state.events);
        final syncedIndex = syncedList.indexWhere((e) => e.id == eventId);
        if (syncedIndex != -1) {
          syncedList[syncedIndex] = syncedList[syncedIndex].copyWith(participantCount: finalCount);
          state = state.copyWith(events: syncedList);
        }
      }
    } catch (e) {
      // Rollback on failure
      final rollbackList = List<EventEntity>.from(state.events);
      final rollbackIndex = rollbackList.indexWhere((e) => e.id == eventId);
      if (rollbackIndex != -1) {
        rollbackList[rollbackIndex] = original;
        state = state.copyWith(events: rollbackList);
      }
    }
  }

  /// Fast optimistic RSVP cancellation across the list.
  Future<void> cancelRsvp(String eventId) async {
    final originalIndex = state.events.indexWhere((e) => e.id == eventId);
    if (originalIndex == -1) return;

    final original = state.events[originalIndex];
    final wasGoing = original.userRsvpStatus == EventRsvpStatus.going;

    final updated = original.copyWith(
      clearUserRsvp: true,
      participantCount: wasGoing ? (original.participantCount - 1).clamp(0, 999999) : original.participantCount,
    );

    final updatedList = List<EventEntity>.from(state.events);
    updatedList[originalIndex] = updated;
    state = state.copyWith(events: updatedList);

    try {
      final res = await _repository.cancelRsvp(eventId);
      final finalCount = (res['participantCount'] as num?)?.toInt() ?? updated.participantCount;
      if (finalCount != updated.participantCount) {
        final syncedList = List<EventEntity>.from(state.events);
        final syncedIndex = syncedList.indexWhere((e) => e.id == eventId);
        if (syncedIndex != -1) {
          syncedList[syncedIndex] = syncedList[syncedIndex].copyWith(participantCount: finalCount);
          state = state.copyWith(events: syncedList);
        }
      }
    } catch (e) {
      // Rollback
      final rollbackList = List<EventEntity>.from(state.events);
      final rollbackIndex = rollbackList.indexWhere((e) => e.id == eventId);
      if (rollbackIndex != -1) {
        rollbackList[rollbackIndex] = original;
        state = state.copyWith(events: rollbackList);
      }
    }
  }

  /// Add a newly created event into the current list.
  void onEventCreated(EventEntity newEvent) {
    state = state.copyWith(events: [newEvent, ...state.events]);
  }

  /// Update an existing event in the current list.
  void onEventUpdated(EventEntity updatedEvent) {
    final updatedList = state.events.map((e) => e.id == updatedEvent.id ? updatedEvent : e).toList();
    state = state.copyWith(events: updatedList);
  }

  /// Handle event cancellation in the list.
  void onEventCancelled(String eventId) {
    if (state.selectedTimeframe == 'upcoming') {
      // Filter out of upcoming discovery
      state = state.copyWith(
        events: state.events.where((e) => e.id != eventId).toList(),
      );
    } else {
      // Mark as cancelled
      final updatedList = state.events.map((e) {
        if (e.id == eventId) {
          return e.copyWith(status: 'cancelled');
        }
        return e;
      }).toList();
      state = state.copyWith(events: updatedList);
    }
  }
}

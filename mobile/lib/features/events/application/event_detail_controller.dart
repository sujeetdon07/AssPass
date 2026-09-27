import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/events_repository.dart';
import '../domain/entities/event_entity.dart';
import '../domain/entities/event_rsvp_status.dart';
import 'event_detail_state.dart';
import 'events_controller.dart';

/// Family provider for [EventDetailController] keyed by [eventId].
final eventDetailControllerProvider =
    StateNotifierProvider.family<EventDetailController, EventDetailState, String>(
  (ref, eventId) {
    final repository = ref.watch(eventsRepositoryProvider);
    final eventsController = ref.watch(eventsControllerProvider.notifier);
    return EventDetailController(eventId, repository, eventsController);
  },
);

/// StateNotifier controlling event details, RSVP status, cancellation, and participants.
class EventDetailController extends StateNotifier<EventDetailState> {
  EventDetailController(
    this.eventId,
    this._repository,
    this._eventsController,
  ) : super(const EventDetailState()) {
    loadEvent();
  }

  final String eventId;
  final EventsRepository _repository;
  final EventsController _eventsController;

  /// Load event details and initial participants list.
  Future<void> loadEvent() async {
    state = state.copyWith(status: EventDetailStatus.loading, errorMessage: null);

    try {
      final event = await _repository.getEventById(eventId);
      state = state.copyWith(status: EventDetailStatus.loaded, event: event);
      loadParticipants();
    } catch (e, st) {
      debugPrint('[EventDetailController] loadEvent error: $e\n$st');
      state = state.copyWith(
        status: EventDetailStatus.error,
        errorMessage: 'Unable to load event details. Tap retry.',
      );
    }
  }

  /// Load participants list for the event.
  Future<void> loadParticipants() async {
    if (state.isLoadingParticipants) return;
    state = state.copyWith(isLoadingParticipants: true);

    try {
      final participants = await _repository.getParticipants(eventId);
      state = state.copyWith(
        participants: participants,
        isLoadingParticipants: false,
      );
    } catch (e) {
      debugPrint('[EventDetailController] loadParticipants error: $e');
      state = state.copyWith(isLoadingParticipants: false);
    }
  }

  /// RSVP to the event.
  Future<bool> rsvp(EventRsvpStatus status) async {
    final currentEvent = state.event;
    if (currentEvent == null || state.isActionLoading) return false;

    state = state.copyWith(isActionLoading: true, errorMessage: null);

    try {
      final res = await _repository.rsvpEvent(eventId, status: status);
      final newCount = (res['participantCount'] as num?)?.toInt() ??
          (currentEvent.userRsvpStatus == EventRsvpStatus.going
              ? currentEvent.participantCount
              : currentEvent.participantCount + 1);

      final updatedEvent = currentEvent.copyWith(
        userRsvpStatus: status,
        participantCount: newCount,
      );

      state = state.copyWith(
        event: updatedEvent,
        isActionLoading: false,
        actionMessage: status == EventRsvpStatus.going
            ? "You're attending this event!"
            : 'Saved to your interested events.',
      );

      // Sync parent list controller
      _eventsController.onEventUpdated(updatedEvent);
      loadParticipants();
      return true;
    } catch (e, st) {
      debugPrint('[EventDetailController] rsvp error: $e\n$st');
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: 'Failed to update RSVP. Please try again.',
      );
      return false;
    }
  }

  /// Cancel RSVP.
  Future<bool> cancelRsvp() async {
    final currentEvent = state.event;
    if (currentEvent == null || state.isActionLoading) return false;

    state = state.copyWith(isActionLoading: true, errorMessage: null);

    try {
      final res = await _repository.cancelRsvp(eventId);
      final newCount = (res['participantCount'] as num?)?.toInt() ??
          (currentEvent.userRsvpStatus == EventRsvpStatus.going
              ? (currentEvent.participantCount - 1).clamp(0, 999999)
              : currentEvent.participantCount);

      final updatedEvent = currentEvent.copyWith(
        clearUserRsvp: true,
        participantCount: newCount,
      );

      state = state.copyWith(
        event: updatedEvent,
        isActionLoading: false,
        actionMessage: 'RSVP removed.',
      );

      // Sync parent list controller
      _eventsController.onEventUpdated(updatedEvent);
      loadParticipants();
      return true;
    } catch (e, st) {
      debugPrint('[EventDetailController] cancelRsvp error: $e\n$st');
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: 'Failed to cancel RSVP. Please try again.',
      );
      return false;
    }
  }

  /// Cancel the event (organizer only).
  Future<bool> cancelEvent({String? reason}) async {
    final currentEvent = state.event;
    if (currentEvent == null || state.isActionLoading) return false;

    state = state.copyWith(isActionLoading: true, errorMessage: null);

    try {
      final updated = await _repository.cancelEvent(eventId, reason: reason);
      state = state.copyWith(
        event: updated,
        isActionLoading: false,
        actionMessage: 'Event has been cancelled.',
      );

      // Sync parent list controller
      _eventsController.onEventCancelled(eventId);
      return true;
    } catch (e, st) {
      debugPrint('[EventDetailController] cancelEvent error: $e\n$st');
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: 'Failed to cancel event. Please try again.',
      );
      return false;
    }
  }

  /// Report the event via Trust & Safety system.
  Future<bool> reportEvent(String reason, {String? details}) async {
    try {
      await _repository.reportEvent(eventId, reason: reason, details: details);
      state = state.copyWith(actionMessage: 'Thank you for your report. Our team will review it.');
      return true;
    } catch (e, st) {
      debugPrint('[EventDetailController] reportEvent error: $e\n$st');
      state = state.copyWith(errorMessage: 'Unable to submit report at this time.');
      return false;
    }
  }

  /// Set event directly if pre-loaded from list.
  void setInitialEvent(EventEntity event) {
    if (state.event == null) {
      state = state.copyWith(status: EventDetailStatus.loaded, event: event);
      loadParticipants();
    }
  }
}

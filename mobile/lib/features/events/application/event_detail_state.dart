import '../domain/entities/event_entity.dart';
import '../domain/entities/event_participant_entity.dart';

enum EventDetailStatus {
  initial,
  loading,
  loaded,
  error,
}

/// State for the Event Detail screen.
class EventDetailState {
  const EventDetailState({
    this.status = EventDetailStatus.initial,
    this.event,
    this.participants = const [],
    this.isLoadingParticipants = false,
    this.isActionLoading = false,
    this.errorMessage,
    this.actionMessage,
  });

  final EventDetailStatus status;
  final EventEntity? event;
  final List<EventParticipantEntity> participants;
  final bool isLoadingParticipants;
  final bool isActionLoading;
  final String? errorMessage;
  final String? actionMessage;

  bool get isLoading => status == EventDetailStatus.loading;
  bool get isLoaded => status == EventDetailStatus.loaded;
  bool get hasError => status == EventDetailStatus.error;

  EventDetailState copyWith({
    EventDetailStatus? status,
    EventEntity? event,
    List<EventParticipantEntity>? participants,
    bool? isLoadingParticipants,
    bool? isActionLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? actionMessage,
    bool clearActionMessage = false,
  }) {
    return EventDetailState(
      status: status ?? this.status,
      event: event ?? this.event,
      participants: participants ?? this.participants,
      isLoadingParticipants: isLoadingParticipants ?? this.isLoadingParticipants,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      actionMessage: clearActionMessage ? null : (actionMessage ?? this.actionMessage),
    );
  }
}

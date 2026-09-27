import '../domain/entities/event_category.dart';
import '../domain/entities/event_entity.dart';

enum EventsStatus {
  initial,
  loading,
  refreshing,
  loaded,
  loadingMore,
  error,
}

/// State for the Events discovery list.
class EventsState {
  const EventsState({
    this.status = EventsStatus.initial,
    this.events = const [],
    this.selectedCategory,
    this.selectedTimeframe = 'upcoming',
    this.localityFilter,
    this.communityFilter,
    this.hasMore = false,
    this.nextCursor,
    this.errorMessage,
  });

  final EventsStatus status;
  final List<EventEntity> events;
  final EventCategory? selectedCategory;
  final String selectedTimeframe;
  final String? localityFilter;
  final String? communityFilter;
  final bool hasMore;
  final String? nextCursor;
  final String? errorMessage;

  bool get isLoading => status == EventsStatus.loading;
  bool get isRefreshing => status == EventsStatus.refreshing;
  bool get isLoadingMore => status == EventsStatus.loadingMore;
  bool get isLoaded => status == EventsStatus.loaded;
  bool get hasError => status == EventsStatus.error;
  bool get isEmpty => isLoaded && events.isEmpty;

  EventsState copyWith({
    EventsStatus? status,
    List<EventEntity>? events,
    EventCategory? selectedCategory,
    bool clearCategory = false,
    String? selectedTimeframe,
    String? localityFilter,
    bool clearLocality = false,
    String? communityFilter,
    bool clearCommunity = false,
    bool? hasMore,
    String? nextCursor,
    String? errorMessage,
  }) {
    return EventsState(
      status: status ?? this.status,
      events: events ?? this.events,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      localityFilter: clearLocality ? null : (localityFilter ?? this.localityFilter),
      communityFilter: clearCommunity ? null : (communityFilter ?? this.communityFilter),
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      errorMessage: errorMessage,
    );
  }
}

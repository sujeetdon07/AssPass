import 'package:flutter/foundation.dart';
import '../domain/models/notification_item.dart';

@immutable
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.selectedFilter = NotificationFilter.all,
    this.errorMessage,
  });

  final List<NotificationItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final NotificationFilter selectedFilter;
  final String? errorMessage;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    bool clearNextCursor = false,
    NotificationFilter? selectedFilter,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      selectedFilter: selectedFilter ?? this.selectedFilter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationsState &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          isLoading == other.isLoading &&
          isLoadingMore == other.isLoadingMore &&
          hasMore == other.hasMore &&
          nextCursor == other.nextCursor &&
          selectedFilter == other.selectedFilter &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(items),
        isLoading,
        isLoadingMore,
        hasMore,
        nextCursor,
        selectedFilter,
        errorMessage,
      );
}

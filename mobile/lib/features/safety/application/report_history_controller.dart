import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/safety_repository.dart';
import '../domain/models/safety_report_item.dart';

class ReportHistoryState {
  const ReportHistoryState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
  });

  final List<SafetyReportItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  bool get hasError => error != null;

  ReportHistoryState copyWith({
    List<SafetyReportItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    Object? error = _sentinel,
  }) {
    return ReportHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: identical(error, _sentinel)
          ? this.error
          : (error == null ? null : error as String?),
    );
  }

  static const Object _sentinel = Object();
}

final reportHistoryControllerProvider =
    AutoDisposeNotifierProvider<ReportHistoryController, ReportHistoryState>(
  ReportHistoryController.new,
);

class ReportHistoryController extends AutoDisposeNotifier<ReportHistoryState> {
  @override
  ReportHistoryState build() {
    Future.microtask(load);
    return const ReportHistoryState(isLoading: true);
  }

  SafetyRepository get _repo => ref.read(safetyRepositoryProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getMyReports(limit: 20);
      state = ReportHistoryState(
        items: result.items,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load report history. Please try again.',
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getMyReports(
        limit: 20,
        cursor: state.nextCursor,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

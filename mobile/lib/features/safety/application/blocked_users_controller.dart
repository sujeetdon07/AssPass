import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/safety_repository.dart';
import '../domain/models/blocked_user_record.dart';

/// State for the blocked users list.
class BlockedUsersState {
  const BlockedUsersState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
  });

  final List<BlockedUserRecord> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  bool get hasError => error != null;

  BlockedUsersState copyWith({
    List<BlockedUserRecord>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    Object? error = _sentinel,
  }) {
    return BlockedUsersState(
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

final blockedUsersControllerProvider =
    AutoDisposeNotifierProvider<BlockedUsersController, BlockedUsersState>(
  BlockedUsersController.new,
);

class BlockedUsersController extends AutoDisposeNotifier<BlockedUsersState> {
  @override
  BlockedUsersState build() {
    // Trigger initial load immediately
    Future.microtask(load);
    return const BlockedUsersState(isLoading: true);
  }

  SafetyRepository get _repo => ref.read(safetyRepositoryProvider);

  /// Load the first page of blocked users.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getBlockedUsers(limit: 20);
      state = BlockedUsersState(
        items: result.items,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load blocked users. Please try again.',
      );
    }
  }

  /// Load the next page of blocked users.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getBlockedUsers(
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

  /// Unblock a user and remove them from local state optimistically.
  Future<bool> unblock(String userId) async {
    final previousItems = state.items;
    // Optimistic removal
    state = state.copyWith(
      items: state.items
          .where((r) => r.blockedUserId != userId)
          .toList(),
    );
    try {
      await _repo.unblockUser(userId);
      return true;
    } catch (_) {
      // Rollback
      state = state.copyWith(items: previousItems);
      return false;
    }
  }
}

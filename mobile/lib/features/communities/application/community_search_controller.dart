import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/communities_repository.dart';
import '../domain/entities/community_entity.dart';

class CommunitySearchState {
  const CommunitySearchState({
    this.isLoading = false,
    this.query = '',
    this.results = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final String query;
  final List<CommunityEntity> results;
  final String? errorMessage;

  bool get isEmpty => !isLoading && query.isNotEmpty && results.isEmpty;

  CommunitySearchState copyWith({
    bool? isLoading,
    String? query,
    List<CommunityEntity>? results,
    String? errorMessage,
  }) {
    return CommunitySearchState(
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      results: results ?? this.results,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for [CommunitySearchController].
final communitySearchControllerProvider = StateNotifierProvider.autoDispose<
    CommunitySearchController, CommunitySearchState>((ref) {
  final repository = ref.watch(communitiesRepositoryProvider);
  return CommunitySearchController(repository);
});

/// StateNotifier controlling community search query execution and results.
class CommunitySearchController extends StateNotifier<CommunitySearchState> {
  CommunitySearchController(this._repository)
      : super(const CommunitySearchState());

  final CommunitiesRepository _repository;

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const CommunitySearchState();
      return;
    }

    state = state.copyWith(isLoading: true, query: trimmed, errorMessage: null);

    try {
      final page = await _repository.getCommunities(
        search: trimmed,
        scope: 'all',
        limit: 30,
      );

      state = state.copyWith(
        isLoading: false,
        results: page.communities,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search failed. Check connection and try again.',
      );
    }
  }

  void clear() {
    state = const CommunitySearchState();
  }
}

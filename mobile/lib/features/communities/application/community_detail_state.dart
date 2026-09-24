import '../../feed/domain/entities/post_entity.dart';
import '../domain/entities/community_entity.dart';

class CommunityDetailState {
  const CommunityDetailState({
    this.community,
    this.isLoading = false,
    this.isActionLoading = false,
    this.posts = const [],
    this.hasMorePosts = false,
    this.nextPostsCursor,
    this.isLoadingPosts = false,
    this.isLoadingMorePosts = false,
    this.errorMessage,
    this.postsErrorMessage,
  });

  final CommunityEntity? community;
  final bool isLoading;
  final bool isActionLoading;
  final List<PostEntity> posts;
  final bool hasMorePosts;
  final String? nextPostsCursor;
  final bool isLoadingPosts;
  final bool isLoadingMorePosts;
  final String? errorMessage;
  final String? postsErrorMessage;

  bool get isMember => community?.currentUserMember ?? false;
  bool get isOwner => community?.isOwner ?? false;
  bool get isModerator => community?.isModerator ?? false;
  bool get isPrivate => community?.isPrivate ?? false;
  bool get canViewPosts => !isPrivate || isMember;

  CommunityDetailState copyWith({
    CommunityEntity? community,
    bool? isLoading,
    bool? isActionLoading,
    List<PostEntity>? posts,
    bool? hasMorePosts,
    String? nextPostsCursor,
    bool? isLoadingPosts,
    bool? isLoadingMorePosts,
    String? errorMessage,
    String? postsErrorMessage,
  }) {
    return CommunityDetailState(
      community: community ?? this.community,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      posts: posts ?? this.posts,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      nextPostsCursor: nextPostsCursor ?? this.nextPostsCursor,
      isLoadingPosts: isLoadingPosts ?? this.isLoadingPosts,
      isLoadingMorePosts: isLoadingMorePosts ?? this.isLoadingMorePosts,
      errorMessage: errorMessage ?? this.errorMessage,
      postsErrorMessage: postsErrorMessage ?? this.postsErrorMessage,
    );
  }
}

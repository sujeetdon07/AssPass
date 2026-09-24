import '../../../feed/data/models/post_model.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_member_entity.dart';
import 'community_member_model.dart';
import 'community_model.dart';

/// Paginated communities result.
class CommunitiesPageModel {
  const CommunitiesPageModel({
    required this.communities,
    this.nextCursor,
    required this.hasMore,
  });

  final List<CommunityEntity> communities;
  final String? nextCursor;
  final bool hasMore;

  factory CommunitiesPageModel.fromJson(Map<String, dynamic> json) {
    final rawCommunities =
        (json['communities'] ?? json['items']) as List<dynamic>? ?? [];
    return CommunitiesPageModel(
      communities: rawCommunities
          .map(
            (item) => CommunityModel.fromJson(item as Map<String, dynamic>)
                .toEntity(),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

/// Paginated community members result.
class CommunityMembersPageModel {
  const CommunityMembersPageModel({
    required this.members,
    this.nextCursor,
    required this.hasMore,
  });

  final List<CommunityMemberEntity> members;
  final String? nextCursor;
  final bool hasMore;

  factory CommunityMembersPageModel.fromJson(Map<String, dynamic> json) {
    final rawMembers =
        (json['members'] ?? json['items']) as List<dynamic>? ?? [];
    return CommunityMembersPageModel(
      members: rawMembers
          .map(
            (item) =>
                CommunityMemberModel.fromJson(item as Map<String, dynamic>)
                    .toEntity(),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

/// Paginated community posts result.
class CommunityPostsPageModel {
  const CommunityPostsPageModel({
    required this.posts,
    this.nextCursor,
    required this.hasMore,
  });

  final List<PostEntity> posts;
  final String? nextCursor;
  final bool hasMore;

  factory CommunityPostsPageModel.fromJson(Map<String, dynamic> json) {
    final rawPosts = (json['posts'] ?? json['items']) as List<dynamic>? ?? [];
    return CommunityPostsPageModel(
      posts: rawPosts
          .map(
            (item) =>
                PostModel.fromJson(item as Map<String, dynamic>).toEntity(),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

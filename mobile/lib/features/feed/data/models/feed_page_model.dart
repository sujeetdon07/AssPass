import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import 'comment_model.dart';
import 'post_model.dart';

/// Paginated community feed result.
class FeedPageModel {
  const FeedPageModel({
    required this.posts,
    this.nextCursor,
    required this.hasMore,
    this.scope = 'local',
  });

  final List<PostEntity> posts;
  final String? nextCursor;
  final bool hasMore;
  final String scope;

  factory FeedPageModel.fromJson(Map<String, dynamic> json) {
    final rawPosts = json['posts'] as List<dynamic>? ?? [];
    return FeedPageModel(
      posts: rawPosts
          .map(
            (item) =>
                PostModel.fromJson(item as Map<String, dynamic>).toEntity(),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
      scope: json['scope'] as String? ?? 'local',
    );
  }
}

/// Paginated comments result.
class CommentsPageModel {
  const CommentsPageModel({
    required this.comments,
    this.nextCursor,
    required this.hasMore,
  });

  final List<CommentEntity> comments;
  final String? nextCursor;
  final bool hasMore;

  factory CommentsPageModel.fromJson(Map<String, dynamic> json) {
    final rawComments = json['comments'] as List<dynamic>? ?? [];
    return CommentsPageModel(
      comments: rawComments
          .map(
            (item) =>
                CommentModel.fromJson(item as Map<String, dynamic>).toEntity(),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

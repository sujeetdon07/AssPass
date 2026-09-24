import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/comment_entity.dart';
import '../domain/entities/post_entity.dart';
import '../data/repositories/feed_repository.dart';
import 'feed_controller.dart';

/// State for single post detail screen including comments list.
class PostDetailState {
  const PostDetailState({
    this.post,
    this.comments = const [],
    this.isLoadingPost = false,
    this.isLoadingComments = false,
    this.isLoadingMoreComments = false,
    this.isSubmittingComment = false,
    this.hasMoreComments = false,
    this.nextCommentsCursor,
    this.errorMessage,
  });

  final PostEntity? post;
  final List<CommentEntity> comments;
  final bool isLoadingPost;
  final bool isLoadingComments;
  final bool isLoadingMoreComments;
  final bool isSubmittingComment;
  final bool hasMoreComments;
  final String? nextCommentsCursor;
  final String? errorMessage;

  PostDetailState copyWith({
    PostEntity? post,
    List<CommentEntity>? comments,
    bool? isLoadingPost,
    bool? isLoadingComments,
    bool? isLoadingMoreComments,
    bool? isSubmittingComment,
    bool? hasMoreComments,
    String? nextCommentsCursor,
    String? errorMessage,
  }) {
    return PostDetailState(
      post: post ?? this.post,
      comments: comments ?? this.comments,
      isLoadingPost: isLoadingPost ?? this.isLoadingPost,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
      isLoadingMoreComments:
          isLoadingMoreComments ?? this.isLoadingMoreComments,
      isSubmittingComment: isSubmittingComment ?? this.isSubmittingComment,
      hasMoreComments: hasMoreComments ?? this.hasMoreComments,
      nextCommentsCursor: nextCommentsCursor ?? this.nextCommentsCursor,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for [PostDetailController] scoped by [postId].
final postDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<PostDetailController, PostDetailState, String>((ref, postId) {
  final repository = ref.watch(feedRepositoryProvider);
  return PostDetailController(postId, repository, ref);
});

/// Controller managing single post detail and comments thread.
class PostDetailController extends StateNotifier<PostDetailState> {
  PostDetailController(
    this._postId,
    this._repository,
    this._ref,
  ) : super(const PostDetailState()) {
    loadPostAndComments();
  }

  final String _postId;
  final FeedRepository _repository;
  final Ref _ref;

  /// Load post details and comments thread concurrently.
  Future<void> loadPostAndComments() async {
    state = state.copyWith(isLoadingPost: true, isLoadingComments: true);

    try {
      final postFuture = _repository.getPostById(_postId);
      final commentsFuture = _repository.getComments(postId: _postId);

      final results = await Future.wait([postFuture, commentsFuture]);
      final post = results[0] as PostEntity;
      final commentsPage = results[1] as dynamic;

      state = state.copyWith(
        post: post,
        comments: commentsPage.comments as List<CommentEntity>,
        hasMoreComments: commentsPage.hasMore as bool,
        nextCommentsCursor: commentsPage.nextCursor as String?,
        isLoadingPost: false,
        isLoadingComments: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingPost: false,
        isLoadingComments: false,
        errorMessage: 'Unable to load post details.',
      );
    }
  }

  /// Load next page of comments.
  Future<void> loadMoreComments() async {
    if (!state.hasMoreComments ||
        state.isLoadingMoreComments ||
        state.nextCommentsCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMoreComments: true);

    try {
      final page = await _repository.getComments(
        postId: _postId,
        cursor: state.nextCommentsCursor,
      );

      final existingIds = state.comments.map((c) => c.id).toSet();
      final newComments =
          page.comments.where((c) => !existingIds.contains(c.id)).toList();

      state = state.copyWith(
        comments: [...state.comments, ...newComments],
        hasMoreComments: page.hasMore,
        nextCommentsCursor: page.nextCursor,
        isLoadingMoreComments: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMoreComments: false);
    }
  }

  /// Add a new comment to this post.
  Future<bool> submitComment(String content) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isSubmittingComment: true);

    try {
      final newComment = await _repository.createComment(
        postId: _postId,
        content: content.trim(),
      );

      final updatedComments = [newComment, ...state.comments];
      final currentPost = state.post;
      final updatedPost = currentPost?.copyWith(
        commentCount: currentPost.commentCount + 1,
      );

      state = state.copyWith(
        comments: updatedComments,
        post: updatedPost,
        isSubmittingComment: false,
      );

      if (updatedPost != null) {
        _ref.read(feedControllerProvider.notifier).updatePost(updatedPost);
      }

      return true;
    } catch (_) {
      state = state.copyWith(isSubmittingComment: false);
      return false;
    }
  }

  /// Delete a comment authored by the current user.
  Future<bool> deleteComment(String commentId) async {
    try {
      await _repository.deleteComment(commentId);

      final updatedComments =
          state.comments.where((c) => c.id != commentId).toList();
      final currentPost = state.post;
      final updatedPost = currentPost?.copyWith(
        commentCount:
            currentPost.commentCount > 0 ? currentPost.commentCount - 1 : 0,
      );

      state = state.copyWith(
        comments: updatedComments,
        post: updatedPost,
      );

      if (updatedPost != null) {
        _ref.read(feedControllerProvider.notifier).updatePost(updatedPost);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Optimistically toggle like on this post.
  Future<void> toggleLike() async {
    final currentPost = state.post;
    if (currentPost == null) return;

    final newLiked = !currentPost.currentUserLiked;
    final newCount = newLiked
        ? currentPost.likeCount + 1
        : (currentPost.likeCount > 0 ? currentPost.likeCount - 1 : 0);

    final updated = currentPost.copyWith(
      currentUserLiked: newLiked,
      likeCount: newCount,
    );

    state = state.copyWith(post: updated);
    _ref.read(feedControllerProvider.notifier).toggleLike(_postId);
  }

  /// Delete this post and notify FeedController.
  Future<bool> deletePost() async {
    try {
      await _repository.deletePost(_postId);
      _ref.read(feedControllerProvider.notifier).removePost(_postId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

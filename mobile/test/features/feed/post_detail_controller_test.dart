import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/feed/application/post_detail_controller.dart';
import 'package:aaspaas/features/feed/data/models/feed_page_model.dart';
import 'package:aaspaas/features/feed/data/repositories/feed_repository.dart';
import 'package:aaspaas/features/feed/domain/entities/comment_entity.dart';
import 'package:aaspaas/features/feed/domain/entities/post_entity.dart';

class _FakeFeedRepository extends Fake implements FeedRepository {
  late PostEntity returnPost;
  List<CommentEntity> returnComments = [];
  bool shouldThrow = false;
  int deletePostCount = 0;
  int deleteCommentCount = 0;

  @override
  Future<PostEntity> getPostById(String postId) async {
    if (shouldThrow) throw Exception('Post not found');
    return returnPost;
  }

  @override
  Future<CommentsPageModel> getComments({
    required String postId,
    String? cursor,
    int limit = 20,
  }) async {
    if (shouldThrow) throw Exception('Failed to load comments');
    return CommentsPageModel(
      comments: returnComments,
      hasMore: false,
    );
  }

  @override
  Future<CommentEntity> createComment({
    required String postId,
    required String content,
  }) async {
    return CommentEntity(
      id: 'comm-new',
      postId: postId,
      authorId: 'user-1',
      authorName: 'Test Neighbor',
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteComment(String commentId) async {
    deleteCommentCount++;
  }

  @override
  Future<void> deletePost(String postId) async {
    deletePostCount++;
  }

  @override
  Future<Map<String, dynamic>> likePost(String postId) async {
    return {'liked': true, 'likeCount': 1};
  }

  @override
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    return {'liked': false, 'likeCount': 0};
  }
}

void main() {
  late _FakeFeedRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _FakeFeedRepository();
    repository.returnPost = PostEntity(
      id: 'post-1',
      authorId: 'author-1',
      authorName: 'Author Neighbor',
      content: 'Discussion post',
      category: PostCategory.general,
      likeCount: 0,
      commentCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    repository.returnComments = [
      CommentEntity(
        id: 'comm-1',
        postId: 'post-1',
        authorId: 'author-2',
        authorName: 'Reply Neighbor',
        content: 'Helpful answer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('PostDetailController', () {
    test('loadPostAndComments loads post and comments thread', () async {
      final controller =
          container.read(postDetailControllerProvider('post-1').notifier);
      await controller.loadPostAndComments();

      final state = container.read(postDetailControllerProvider('post-1'));
      expect(state.post, isNotNull);
      expect(state.post!.content, 'Discussion post');
      expect(state.comments.length, 1);
      expect(state.comments.first.content, 'Helpful answer');
      expect(state.errorMessage, isNull);
    });

    test('submitComment adds comment and increments commentCount', () async {
      final controller =
          container.read(postDetailControllerProvider('post-1').notifier);
      await controller.loadPostAndComments();

      final success = await controller.submitComment('Great suggestion!');
      expect(success, isTrue);

      final state = container.read(postDetailControllerProvider('post-1'));
      expect(state.comments.length, 2);
      expect(state.comments.first.content, 'Great suggestion!');
      expect(state.post!.commentCount, 1);
    });

    test('deleteComment removes comment and decrements commentCount', () async {
      final controller =
          container.read(postDetailControllerProvider('post-1').notifier);
      await controller.loadPostAndComments();

      final success = await controller.deleteComment('comm-1');
      expect(success, isTrue);
      expect(repository.deleteCommentCount, 1);

      final state = container.read(postDetailControllerProvider('post-1'));
      expect(state.comments, isEmpty);
    });

    test('deletePost delegates to repository', () async {
      final controller =
          container.read(postDetailControllerProvider('post-1').notifier);
      await controller.loadPostAndComments();

      final success = await controller.deletePost();
      expect(success, isTrue);
      expect(repository.deletePostCount, 1);
    });
  });
}

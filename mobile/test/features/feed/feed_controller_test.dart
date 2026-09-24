import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/feed/application/feed_controller.dart';
import 'package:aaspaas/features/feed/application/feed_state.dart';
import 'package:aaspaas/features/feed/data/models/feed_page_model.dart';
import 'package:aaspaas/features/feed/data/repositories/feed_repository.dart';
import 'package:aaspaas/features/feed/domain/entities/post_entity.dart';

class _FakeFeedRepository extends Fake implements FeedRepository {
  List<PostEntity> returnPosts = [];
  bool shouldThrow = false;
  int likeCallCount = 0;
  int unlikeCallCount = 0;

  @override
  Future<FeedPageModel> getFeed({
    String? cursor,
    int limit = 20,
    String? category,
    String scope = 'local',
  }) async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return FeedPageModel(
      posts: returnPosts,
      hasMore: returnPosts.length >= limit,
      nextCursor: returnPosts.isNotEmpty ? 'dummy-cursor' : null,
      scope: scope,
    );
  }

  @override
  Future<Map<String, dynamic>> likePost(String postId) async {
    likeCallCount++;
    if (shouldThrow) throw Exception('Failed to like');
    return {'liked': true, 'likeCount': 1};
  }

  @override
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    unlikeCallCount++;
    if (shouldThrow) throw Exception('Failed to unlike');
    return {'liked': false, 'likeCount': 0};
  }
}

PostEntity createTestPost({
  String id = 'post-1',
  String content = 'Hello neighbors!',
  PostCategory category = PostCategory.general,
  int likeCount = 0,
  bool currentUserLiked = false,
}) {
  return PostEntity(
    id: id,
    authorId: 'author-1',
    authorName: 'Neighbor A',
    content: content,
    category: category,
    locality: 'Koramangala',
    city: 'Bengaluru',
    likeCount: likeCount,
    currentUserLiked: currentUserLiked,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late _FakeFeedRepository repository;

  setUp(() {
    repository = _FakeFeedRepository();
  });

  group('FeedController', () {
    test('initial load fetches posts successfully', () async {
      final post = createTestPost();
      repository.returnPosts = [post];

      final controller = FeedController(repository);
      await controller.loadFeed();

      expect(controller.state.status, FeedStatus.loaded);
      expect(controller.state.posts.length, 1);
      expect(controller.state.posts.first.content, 'Hello neighbors!');
      expect(controller.state.errorMessage, isNull);
    });

    test('error during load sets error status and message', () async {
      repository.shouldThrow = true;

      final controller = FeedController(repository);
      await controller.loadFeed();

      expect(controller.state.status, FeedStatus.error);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.posts, isEmpty);
    });

    test('optimistic like increments likeCount and updates currentUserLiked',
        () async {
      final post = createTestPost(likeCount: 0, currentUserLiked: false);
      repository.returnPosts = [post];

      final controller = FeedController(repository);
      await controller.loadFeed();

      await controller.toggleLike(post.id);

      expect(controller.state.posts.first.currentUserLiked, isTrue);
      expect(controller.state.posts.first.likeCount, 1);
      expect(repository.likeCallCount, 1);
    });

    test('optimistic unlike decrements likeCount and toggles off', () async {
      final post = createTestPost(likeCount: 1, currentUserLiked: true);
      repository.returnPosts = [post];

      final controller = FeedController(repository);
      await controller.loadFeed();

      await controller.toggleLike(post.id);

      expect(controller.state.posts.first.currentUserLiked, isFalse);
      expect(controller.state.posts.first.likeCount, 0);
      expect(repository.unlikeCallCount, 1);
    });

    test('optimistic like rolls back when network request fails', () async {
      final post = createTestPost(likeCount: 0, currentUserLiked: false);
      repository.returnPosts = [post];

      final controller = FeedController(repository);
      await controller.loadFeed();

      repository.shouldThrow = true;
      await controller.toggleLike(post.id);

      // Rolled back
      expect(controller.state.posts.first.currentUserLiked, isFalse);
      expect(controller.state.posts.first.likeCount, 0);
    });

    test('addPost prepends post to the top of feed', () async {
      final existingPost = createTestPost(id: 'p1', content: 'Old post');
      repository.returnPosts = [existingPost];

      final controller = FeedController(repository);
      await controller.loadFeed();

      final newPost = createTestPost(id: 'p2', content: 'Fresh new post');
      controller.addPost(newPost);

      expect(controller.state.posts.length, 2);
      expect(controller.state.posts.first.id, 'p2');
    });

    test('updatePost updates post content and category in-place', () async {
      final post = createTestPost(id: 'p1', content: 'Original');
      repository.returnPosts = [post];

      final controller = FeedController(repository);
      await controller.loadFeed();

      final updated = post.copyWith(content: 'Modified content');
      controller.updatePost(updated);

      expect(controller.state.posts.first.content, 'Modified content');
    });

    test('removePost filters post out of feed', () async {
      final post = createTestPost(id: 'p1');
      repository.returnPosts = [post];

      final controller = FeedController(repository);
      await controller.loadFeed();

      controller.removePost('p1');
      expect(controller.state.posts, isEmpty);
    });

    test('setCategory updates selected category and reloads', () async {
      final controller = FeedController(repository);
      controller.setCategory(PostCategory.alert);

      expect(controller.state.selectedCategory, PostCategory.alert);

      // Tapping same category clears it
      controller.setCategory(PostCategory.alert);
      expect(controller.state.selectedCategory, isNull);
    });
  });
}

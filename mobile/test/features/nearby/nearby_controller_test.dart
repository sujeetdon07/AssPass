import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/feed/data/repositories/feed_repository.dart';
import 'package:aaspaas/features/feed/domain/entities/post_entity.dart';
import 'package:aaspaas/features/nearby/application/nearby_controller.dart';
import 'package:aaspaas/features/nearby/data/models/nearby_page_model.dart';
import 'package:aaspaas/features/nearby/data/repositories/nearby_repository.dart';

class _FakeNearbyRepository extends Fake implements NearbyRepository {
  List<PostEntity> returnPosts = [];
  bool shouldThrow = false;
  String? nextCursor;
  bool hasMore = false;
  int radiusKmPassed = 5;
  PostCategory? categoryPassed;

  @override
  Future<NearbyPageModel> getNearbyPosts({
    required double latitude,
    required double longitude,
    int radius = 5,
    int limit = 20,
    String? cursor,
    PostCategory? category,
  }) async {
    if (shouldThrow) {
      throw Exception('Server unreachable');
    }
    radiusKmPassed = radius;
    categoryPassed = category;
    return NearbyPageModel(
      posts: returnPosts,
      hasMore: hasMore,
      nextCursor: nextCursor,
      radiusKm: radius,
    );
  }
}

class _FakeFeedRepository extends Fake implements FeedRepository {
  int likeCalls = 0;
  int unlikeCalls = 0;
  bool shouldThrow = false;

  @override
  Future<Map<String, dynamic>> likePost(String postId) async {
    likeCalls++;
    if (shouldThrow) throw Exception('Like error');
    return {'liked': true, 'likeCount': 1};
  }

  @override
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    unlikeCalls++;
    if (shouldThrow) throw Exception('Unlike error');
    return {'liked': false, 'likeCount': 0};
  }
}

PostEntity _createNearbyPost({
  String id = 'post-1',
  String content = 'Found lost keys near park',
  String? distance = '350 m away',
  int distanceMeters = 350,
  int likeCount = 2,
  bool currentUserLiked = false,
  PostCategory category = PostCategory.general,
}) {
  return PostEntity(
    id: id,
    authorId: 'user-1',
    authorName: 'Ramesh',
    content: content,
    category: category,
    locality: 'Koramangala',
    city: 'Bengaluru',
    likeCount: likeCount,
    commentCount: 0,
    currentUserLiked: currentUserLiked,
    distance: distance,
    distanceMeters: distanceMeters,
    createdAt: DateTime(2026, 9, 22, 10, 0),
    updatedAt: DateTime(2026, 9, 22, 10, 0),
  );
}

void main() {
  group('NearbyController', () {
    late _FakeNearbyRepository fakeNearbyRepo;
    late _FakeFeedRepository fakeFeedRepo;
    late NearbyController controller;

    setUp(() {
      fakeNearbyRepo = _FakeNearbyRepository();
      fakeFeedRepo = _FakeFeedRepository();
      controller = NearbyController(fakeNearbyRepo, fakeFeedRepo);
    });

    test('initial state has default radius 5 and empty posts', () {
      expect(controller.state.radiusKm, 5);
      expect(controller.state.posts, isEmpty);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.hasMore, isFalse);
    });

    test('loadNearbyPosts fetches posts successfully', () async {
      final posts = [
        _createNearbyPost(id: 'p1', content: 'First nearby'),
        _createNearbyPost(id: 'p2', content: 'Second nearby'),
      ];
      fakeNearbyRepo.returnPosts = posts;
      fakeNearbyRepo.hasMore = true;
      fakeNearbyRepo.nextCursor = 'cursor-123';

      await controller.loadNearbyPosts(latitude: 12.9352, longitude: 77.6245);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.posts.length, 2);
      expect(controller.state.posts.first.id, 'p1');
      expect(controller.state.hasMore, isTrue);
      expect(controller.state.nextCursor, 'cursor-123');
      expect(fakeNearbyRepo.radiusKmPassed, 5);
    });

    test('loadNearbyPosts sets errorMessage on repository failure', () async {
      fakeNearbyRepo.shouldThrow = true;

      await controller.loadNearbyPosts(latitude: 12.9352, longitude: 77.6245);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.posts, isEmpty);
      expect(
        controller.state.errorMessage,
        contains('Unable to load nearby posts'),
      );
    });

    test('setRadius updates radius and reloads posts', () async {
      fakeNearbyRepo.returnPosts = [_createNearbyPost(id: 'p10')];

      await controller.setRadius(10, latitude: 12.9352, longitude: 77.6245);

      expect(controller.state.radiusKm, 10);
      expect(fakeNearbyRepo.radiusKmPassed, 10);
      expect(controller.state.posts.length, 1);
    });

    test('setCategory toggles category filter and reloads', () async {
      await controller.setCategory(
        PostCategory.recommendation,
        latitude: 12.9352,
        longitude: 77.6245,
      );
      expect(controller.state.selectedCategory, PostCategory.recommendation);
      expect(fakeNearbyRepo.categoryPassed, PostCategory.recommendation);

      // Toggling same category clears it
      await controller.setCategory(
        PostCategory.recommendation,
        latitude: 12.9352,
        longitude: 77.6245,
      );
      expect(controller.state.selectedCategory, isNull);
      expect(fakeNearbyRepo.categoryPassed, isNull);
    });

    test(
        'loadMore appends posts when hasMore is true and nextCursor is present',
        () async {
      fakeNearbyRepo.returnPosts = [_createNearbyPost(id: 'p1')];
      fakeNearbyRepo.hasMore = true;
      fakeNearbyRepo.nextCursor = 'cursor-1';
      await controller.loadNearbyPosts(latitude: 12.9352, longitude: 77.6245);
      expect(controller.state.posts.length, 1);

      // Page 2
      fakeNearbyRepo.returnPosts = [_createNearbyPost(id: 'p2')];
      fakeNearbyRepo.hasMore = false;
      fakeNearbyRepo.nextCursor = null;

      await controller.loadMore(latitude: 12.9352, longitude: 77.6245);

      expect(controller.state.posts.length, 2);
      expect(controller.state.posts.map((p) => p.id), ['p1', 'p2']);
      expect(controller.state.hasMore, isFalse);
    });

    test('toggleLike updates likeCount and currentUserLiked optimistically',
        () async {
      fakeNearbyRepo.returnPosts = [
        _createNearbyPost(id: 'p1', likeCount: 3, currentUserLiked: false),
      ];
      await controller.loadNearbyPosts(latitude: 12.9352, longitude: 77.6245);

      await controller.toggleLike('p1');

      expect(controller.state.posts.first.currentUserLiked, isTrue);
      expect(controller.state.posts.first.likeCount, 4);
      expect(fakeFeedRepo.likeCalls, 1);

      // Toggle again to unlike
      await controller.toggleLike('p1');
      expect(controller.state.posts.first.currentUserLiked, isFalse);
      expect(controller.state.posts.first.likeCount, 3);
      expect(fakeFeedRepo.unlikeCalls, 1);
    });

    test('toggleLike reverts optimistic update when server fails', () async {
      fakeNearbyRepo.returnPosts = [
        _createNearbyPost(id: 'p1', likeCount: 5, currentUserLiked: false),
      ];
      await controller.loadNearbyPosts(latitude: 12.9352, longitude: 77.6245);

      fakeFeedRepo.shouldThrow = true;
      await controller.toggleLike('p1');

      // Reverted to original
      expect(controller.state.posts.first.currentUserLiked, isFalse);
      expect(controller.state.posts.first.likeCount, 5);
    });
  });
}

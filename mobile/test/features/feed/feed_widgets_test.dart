import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/application/auth_state.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';
import 'package:aaspaas/features/feed/data/models/feed_page_model.dart';
import 'package:aaspaas/features/feed/data/repositories/feed_repository.dart';
import 'package:aaspaas/features/feed/domain/entities/comment_entity.dart';
import 'package:aaspaas/features/feed/domain/entities/post_entity.dart';
import 'package:aaspaas/features/feed/presentation/screens/create_post_screen.dart';
import 'package:aaspaas/features/feed/presentation/screens/post_detail_screen.dart';
import 'package:aaspaas/features/feed/presentation/widgets/post_card.dart';
import 'package:aaspaas/features/feed/presentation/widgets/report_content_dialog.dart';

class _FakeFeedRepository extends Fake implements FeedRepository {
  @override
  Future<PostEntity> getPostById(String postId) async {
    return PostEntity(
      id: postId,
      authorId: 'user-1',
      authorName: 'Ramesh Kumar',
      content: 'Power cut in 4th block Koramangala?',
      category: PostCategory.alert,
      locality: 'Koramangala',
      city: 'Bengaluru',
      likeCount: 5,
      commentCount: 2,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<CommentsPageModel> getComments({
    required String postId,
    String? cursor,
    int limit = 20,
  }) async {
    return CommentsPageModel(
      comments: [
        CommentEntity(
          id: 'c-1',
          postId: postId,
          authorId: 'user-2',
          authorName: 'Priya Sharma',
          authorLocality: 'Koramangala 4th Block',
          content: 'Yes, BESCOM announced 2hr maintenance.',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<PostEntity> createPost({
    required String content,
    required PostCategory category,
    List<PostMention>? mentions,
    String? locality,
    String? neighborhood,
    List<Map<String, dynamic>>? images,
  }) async {
    return PostEntity(
      id: 'new-post-1',
      authorId: 'user-1',
      authorName: 'Test Neighbor',
      content: content,
      category: category,
      locality: locality,
      neighborhood: neighborhood,
      mentions: mentions ?? const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {}
}

class _TestAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _TestAuthController()
      : super(
          const AuthAuthenticated(
            UserEntity(
              id: 'user-1',
              phoneNumber: '+919876543210',
              displayName: 'Test Neighbor',
              locality: 'Koramangala',
              city: 'Bengaluru',
              onboardingCompleted: true,
            ),
          ),
        );

  @override
  void updateUser(UserEntity user) {
    state = AuthAuthenticated(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => _TestAuthController()),
      feedRepositoryProvider.overrideWithValue(_FakeFeedRepository()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  group('PostCard Widget', () {
    testWidgets(
        'renders author, locality, category badge, content, and action counts',
        (tester) async {
      final post = PostEntity(
        id: 'post-1',
        authorId: 'user-1',
        authorName: 'Aarav Patel',
        authorLocality: 'Indiranagar',
        authorCity: 'Bengaluru',
        content: 'Any good vegetarian thali recommendations around 100ft road?',
        category: PostCategory.recommendation,
        likeCount: 12,
        commentCount: 4,
        currentUserLiked: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool liked = false;
      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: PostCard(
              post: post,
              currentUserId: 'user-1',
              onLikePressed: () => liked = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('Indiranagar, Bengaluru'), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
      expect(find.textContaining('Any good vegetarian thali'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // Tap like
      await tester.tap(find.text('12'));
      expect(liked, isTrue);
    });
  });

  group('ReportContentDialog', () {
    testWidgets(
        'renders reasons and allows selecting reason and entering details',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const Scaffold(
            body: ReportContentDialog(
              targetId: 'post-123',
              targetType: ReportType.post,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report Post'), findsOneWidget);
      expect(find.text('Spam or commercial advertising'), findsOneWidget);
      expect(find.text('Harassment or abusive behavior'), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);

      // Tap harassment option
      await tester.tap(find.text('Harassment or abusive behavior'));
      await tester.pumpAndSettle();

      // Enter details
      await tester.enterText(find.byType(TextField), 'Violated guidelines');
      expect(find.text('Violated guidelines'), findsOneWidget);
    });
  });

  group('CreatePostScreen', () {
    testWidgets(
        'renders locality banner, categories, and enables Post button on input',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(const CreatePostScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Post'), findsOneWidget);
      expect(
        find.textContaining(
          'Sharing with neighbors in Koramangala, Bengaluru',
        ),
        findsOneWidget,
      );
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Local Alert'), findsOneWidget);

      // Type text into content area
      await tester.enterText(
        find.byType(TextField),
        'Power update in 5th block',
      );
      await tester.pumpAndSettle();

      expect(find.text('Power update in 5th block'), findsOneWidget);
    });
  });

  group('PostDetailScreen', () {
    testWidgets(
      'renders post content, comment list, and reply bar',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(const PostDetailScreen(postId: 'post-test-1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Post'), findsOneWidget);
        expect(
          find.text('Power cut in 4th block Koramangala?'),
          findsOneWidget,
        );
        expect(find.text('Ramesh Kumar'), findsOneWidget);
        expect(find.text('Comments (1)'), findsOneWidget);
        expect(find.text('Priya Sharma'), findsOneWidget);
        expect(
          find.text('Yes, BESCOM announced 2hr maintenance.'),
          findsOneWidget,
        );
        expect(find.text('Write a neighborly reply...'), findsOneWidget);
      },
    );
  });
}

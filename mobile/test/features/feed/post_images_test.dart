import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/features/feed/data/models/post_image_model.dart';
import 'package:aaspaas/features/feed/data/models/post_model.dart';
import 'package:aaspaas/features/feed/domain/entities/post_entity.dart';
import 'package:aaspaas/features/feed/domain/entities/post_image_entity.dart';
import 'package:aaspaas/features/feed/presentation/widgets/post_card.dart';
import 'package:aaspaas/features/feed/presentation/widgets/post_media_carousel.dart';
import 'package:aaspaas/shared/widgets/media/app_cached_image.dart';
import 'package:aaspaas/shared/widgets/media/app_multi_image_picker.dart';
import 'package:aaspaas/shared/widgets/media/app_photo_gallery_viewer.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostImage Entity and Model', () {
    test('PostImageModel fromJson parses all fields correctly', () {
      final json = {
        'id': 'img-1',
        'postId': 'post-100',
        'url': 'https://storage.example.com/uploads/photo1.webp',
        'thumbnailUrl': 'https://storage.example.com/uploads/photo1_thumb.webp',
        'mediumUrl': 'https://storage.example.com/uploads/photo1_med.webp',
        'width': 1920,
        'height': 1080,
        'mimeType': 'image/webp',
        'size': 204800,
        'sortOrder': 0,
        'createdAt': '2026-09-29T12:00:00.000Z',
      };

      final model = PostImageModel.fromJson(json);

      expect(model.id, equals('img-1'));
      expect(model.url, equals('https://storage.example.com/uploads/photo1.webp'));
      expect(model.thumbnailUrl, equals('https://storage.example.com/uploads/photo1_thumb.webp'));
      expect(model.mediumUrl, equals('https://storage.example.com/uploads/photo1_med.webp'));
      expect(model.width, equals(1920));
      expect(model.height, equals(1080));
      expect(model.mimeType, equals('image/webp'));
      expect(model.size, equals(204800));
      expect(model.sortOrder, equals(0));
      expect(model.aspectRatio, closeTo(1920 / 1080, 0.01));
    });

    test('PostImageModel handles missing optional fields gracefully', () {
      final json = {
        'id': 'img-2',
        'url': 'https://storage.example.com/uploads/photo2.webp',
      };

      final model = PostImageModel.fromJson(json);

      expect(model.id, equals('img-2'));
      expect(model.url, equals('https://storage.example.com/uploads/photo2.webp'));
      expect(model.thumbnailUrl, equals('https://storage.example.com/uploads/photo2.webp'));
      expect(model.mediumUrl, isNull);
      expect(model.width, isNull);
      expect(model.height, isNull);
      expect(model.aspectRatio, isNull);
      expect(model.sortOrder, equals(0));
    });

    test('PostModel parses attached images list and sorts by sortOrder', () {
      final json = {
        'id': 'post-1',
        'authorId': 'u1',
        'authorName': 'John',
        'content': 'Check out these community garden photos!',
        'category': 'general',
        'createdAt': '2026-09-29T12:00:00.000Z',
        'images': [
          {
            'id': 'img-b',
            'url': 'https://storage.example.com/img2.webp',
            'sortOrder': 1,
          },
          {
            'id': 'img-a',
            'url': 'https://storage.example.com/img1.webp',
            'sortOrder': 0,
          },
        ],
      };

      final model = PostModel.fromJson(json);

      expect(model.images.length, equals(2));
      expect(model.hasImages, isTrue);
      expect(model.images[0].id, equals('img-a'));
      expect(model.images[1].id, equals('img-b'));
    });

    test('PostEntity hasImages is false when images list is empty', () {
      final post = PostEntity(
        id: 'post-no-images',
        authorId: 'u1',
        authorName: 'John',
        content: 'No images here',
        category: PostCategory.general,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        images: const [],
      );

      expect(post.hasImages, isFalse);
    });
  });

  group('PostMediaCarousel Layouts & Behavior', () {
    testWidgets('1 image renders single carousel page with no indicator dots',
        (tester) async {
      const singleImage = PostImageEntity(
        id: 'img-1',
        url: 'https://storage.example.com/img1.webp',
        mediumUrl: 'https://storage.example.com/img1_med.webp',
        width: 1600,
        height: 1200,
      );

      await tester.pumpWidget(
        _buildTestApp(
          const PostMediaCarousel(images: [singleImage]),
        ),
      );
      await tester.pump();

      expect(find.byType(PostMediaCarousel), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(AppCachedImage), findsOneWidget);
      // No indicator dots or counter for single image
      expect(find.text('1/1'), findsNothing);
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('2 images render 2 carousel pages with 2 indicator dots',
        (tester) async {
      final twoImages = [
        const PostImageEntity(
          id: 'img-1',
          url: 'https://storage.example.com/img1.webp',
          mediumUrl: 'https://storage.example.com/img1_med.webp',
        ),
        const PostImageEntity(
          id: 'img-2',
          url: 'https://storage.example.com/img2.webp',
          mediumUrl: 'https://storage.example.com/img2_med.webp',
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          PostMediaCarousel(images: twoImages),
        ),
      );
      await tester.pump();

      expect(find.byType(PostMediaCarousel), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      // Top-right counter shows 1/2
      expect(find.text('1/2'), findsOneWidget);
      // 2 indicator dots rendered
      expect(find.byType(AnimatedContainer), findsNWidgets(2));
      // No +N grid overlay exists
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('3 images render 3 carousel pages with 3 indicator dots',
        (tester) async {
      final threeImages = [
        const PostImageEntity(
          id: 'img-1',
          url: 'https://storage.example.com/img1.webp',
        ),
        const PostImageEntity(
          id: 'img-2',
          url: 'https://storage.example.com/img2.webp',
        ),
        const PostImageEntity(
          id: 'img-3',
          url: 'https://storage.example.com/img3.webp',
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          PostMediaCarousel(images: threeImages),
        ),
      );
      await tester.pump();

      expect(find.byType(PostMediaCarousel), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      // 3 indicator dots rendered
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('4 images render 4 carousel pages with 4 indicator dots',
        (tester) async {
      final fourImages = List.generate(
        4,
        (i) => PostImageEntity(
          id: 'img-$i',
          url: 'https://storage.example.com/img$i.webp',
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          PostMediaCarousel(images: fourImages),
        ),
      );
      await tester.pump();

      expect(find.byType(PostMediaCarousel), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
      // 4 indicator dots rendered
      expect(find.byType(AnimatedContainer), findsNWidgets(4));
      // Confirms NO old +N grid overlay exists
      expect(find.text('+1'), findsNothing);
      expect(find.text('+2'), findsNothing);
    });

    testWidgets('swiping carousel advances page and updates counter and active dot',
        (tester) async {
      final threeImages = [
        const PostImageEntity(
          id: 'img-1',
          url: 'https://storage.example.com/img1.webp',
        ),
        const PostImageEntity(
          id: 'img-2',
          url: 'https://storage.example.com/img2.webp',
        ),
        const PostImageEntity(
          id: 'img-3',
          url: 'https://storage.example.com/img3.webp',
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          PostMediaCarousel(images: threeImages),
        ),
      );
      await tester.pump();

      expect(find.text('1/3'), findsOneWidget);

      // Swipe left on PageView to transition to image 2
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('2/3'), findsOneWidget);
    });

    testWidgets('tapping image invokes onImageTap with active page index',
        (tester) async {
      int? tappedIndex;
      final twoImages = [
        const PostImageEntity(
          id: 'img-1',
          url: 'https://storage.example.com/img1.webp',
        ),
        const PostImageEntity(
          id: 'img-2',
          url: 'https://storage.example.com/img2.webp',
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          PostMediaCarousel(
            images: twoImages,
            onImageTap: (index) => tappedIndex = index,
          ),
        ),
      );
      await tester.pump();

      // Tap active first page
      await tester.tap(find.byType(PageView));
      await tester.pump();

      expect(tappedIndex, equals(0));
    });

    testWidgets('handles legacy posts with >4 images safely without crashing',
        (tester) async {
      final legacyImages = List.generate(
        6,
        (i) => PostImageEntity(
          id: 'legacy-img-$i',
          url: 'https://storage.example.com/legacy$i.webp',
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          PostMediaCarousel(images: legacyImages),
        ),
      );
      await tester.pump();

      expect(find.byType(PostMediaCarousel), findsOneWidget);
      expect(find.text('1/6'), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(6));
    });
  });

  group('Feed Image Limit Enforcement (Max 4 Images)', () {
    testWidgets('AppMultiImagePicker shows 4/4 and hides Add Photo when 4 selected',
        (tester) async {
      final fourUrls = [
        'https://example.com/1.webp',
        'https://example.com/2.webp',
        'https://example.com/3.webp',
        'https://example.com/4.webp',
      ];

      await tester.pumpWidget(
        _buildTestApp(
          AppMultiImagePicker(
            initialUrls: fourUrls,
            maxImages: 4,
            label: 'Photos',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('4/4'), findsOneWidget);
      // Once 4 images are selected, Add Photo action must be hidden
      expect(find.text('Add Photo'), findsNothing);
    });

    testWidgets('AppMultiImagePicker shows Add Photo button when <4 selected',
        (tester) async {
      final twoUrls = [
        'https://example.com/1.webp',
        'https://example.com/2.webp',
      ];

      await tester.pumpWidget(
        _buildTestApp(
          AppMultiImagePicker(
            initialUrls: twoUrls,
            maxImages: 4,
            label: 'Photos',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2/4'), findsOneWidget);
      expect(find.text('Add Photo'), findsOneWidget);
    });
  });

  group('AppPhotoGalleryViewer Component', () {
    testWidgets('renders initial image and page indicator for multiple images',
        (tester) async {
      final images = [
        const PostImageEntity(
          id: 'img-1',
          url: 'https://storage.example.com/img1.webp',
        ),
        const PostImageEntity(
          id: 'img-2',
          url: 'https://storage.example.com/img2.webp',
        ),
        const PostImageEntity(
          id: 'img-3',
          url: 'https://storage.example.com/img3.webp',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppPhotoGalleryViewer(
            imageUrls: images.map((i) => i.url).toList(),
            initialIndex: 0,
          ),
        ),
      );
      await tester.pump();

      // Page counter shows 1 / 3
      expect(find.text('1 / 3'), findsOneWidget);
      // Close button exists
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // PageView is present for swiping
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('close button pops viewer screen', (tester) async {
      final images = [
        const PostImageEntity(
          id: 'img-1',
          url: 'https://storage.example.com/img1.webp',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppPhotoGalleryViewer.show(
                  context,
                  imageUrls: images.map((i) => i.url).toList(),
                  initialIndex: 0,
                );
              },
              child: const Text('Open Gallery'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(AppPhotoGalleryViewer), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(AppPhotoGalleryViewer), findsNothing);
    });
  });

  group('PostCard Integration with PostMediaCarousel', () {
    testWidgets('PostCard renders PostMediaCarousel when images are attached',
        (tester) async {
      final postWithImages = PostEntity(
        id: 'post-with-images',
        authorId: 'user-1',
        authorName: 'Deepa Roy',
        authorLocality: 'Koramangala',
        authorCity: 'Bengaluru',
        content: 'Lovely sunset today from our rooftop garden!',
        category: PostCategory.general,
        likeCount: 15,
        commentCount: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        images: const [
          PostImageEntity(
            id: 'img-sunset-1',
            url: 'https://storage.example.com/sunset1.webp',
            mediumUrl: 'https://storage.example.com/sunset1_med.webp',
          ),
          PostImageEntity(
            id: 'img-sunset-2',
            url: 'https://storage.example.com/sunset2.webp',
            mediumUrl: 'https://storage.example.com/sunset2_med.webp',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          PostCard(
            post: postWithImages,
            currentUserId: 'user-1',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PostMediaCarousel), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(
        find.text('Lovely sunset today from our rooftop garden!'),
        findsOneWidget,
      );
    });

    testWidgets('PostCard without images does not render PostMediaCarousel',
        (tester) async {
      final postWithoutImages = PostEntity(
        id: 'post-no-images',
        authorId: 'user-1',
        authorName: 'Deepa Roy',
        authorLocality: 'Koramangala',
        authorCity: 'Bengaluru',
        content: 'No images attached to this text announcement.',
        category: PostCategory.announcement,
        likeCount: 5,
        commentCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        images: const [],
      );

      await tester.pumpWidget(
        _buildTestApp(
          PostCard(
            post: postWithoutImages,
            currentUserId: 'user-1',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PostMediaCarousel), findsNothing);
      expect(
        find.text('No images attached to this text announcement.'),
        findsOneWidget,
      );
    });
  });
}

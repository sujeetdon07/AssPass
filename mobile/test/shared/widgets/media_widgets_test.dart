import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaspaas/core/theme/app_icons.dart';
import 'package:aaspaas/shared/widgets/avatars/app_avatar.dart';
import 'package:aaspaas/shared/widgets/media/app_cached_image.dart';
import 'package:aaspaas/shared/widgets/media/app_single_image_picker.dart';
import 'package:aaspaas/shared/widgets/media/app_multi_image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('AppAvatar', () {
    testWidgets('renders fallback initials when imageUrl is null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const AppAvatar(
            name: 'Sujeet Patel',
            size: AppAvatarSize.s48,
          ),
        ),
      );

      expect(find.text('SP'), findsOneWidget);
    });

    testWidgets('renders single initial when only one name word provided', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const AppAvatar(
            name: 'Community',
            size: AppAvatarSize.s40,
          ),
        ),
      );

      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('has circular BoxShape decoration for perfect circle presentation', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const AppAvatar(
            name: 'Aaspaas User',
            size: AppAvatarSize.s56,
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(AppAvatar),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(containerFinder);
      final boxDecoration = containerWidget.decoration as BoxDecoration;
      expect(boxDecoration.shape, BoxShape.circle);
    });
  });

  group('AppCachedImage', () {
    testWidgets('renders image placeholder icon when imageUrl is empty', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            width: 100,
            height: 100,
            child: AppCachedImage(
              imageUrl: '',
            ),
          ),
        ),
      );

      expect(find.byIcon(AppIcons.image), findsOneWidget);
    });

    testWidgets('renders custom error widget when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            width: 100,
            height: 100,
            child: AppCachedImage(
              imageUrl: '',
              errorWidget: Text('Custom Error View'),
            ),
          ),
        ),
      );

      expect(find.text('Custom Error View'), findsOneWidget);
    });
  });

  group('AppSingleImagePicker', () {
    testWidgets('renders empty picker state when initialUrl is null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          AppSingleImagePicker(
            label: 'Event Cover',
            onUrlChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Event Cover'), findsOneWidget);
      expect(find.text('Tap to select cover image'), findsOneWidget);
    });

    testWidgets('renders preview with change and remove actions when initialUrl is given', (tester) async {
      String? updatedUrl = 'initial';
      await tester.pumpWidget(
        wrapWithTheme(
          AppSingleImagePicker(
            label: 'Event Cover',
            initialUrl: 'https://example.com/cover.webp',
            onUrlChanged: (url) {
              updatedUrl = url;
            },
          ),
        ),
      );

      expect(find.text('Event Cover'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      // Tap remove button
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(updatedUrl, isNull);
      expect(find.text('Tap to select cover image'), findsOneWidget);
    });
  });

  group('AppMultiImagePicker', () {
    testWidgets('renders initial remote URLs and enforces max count', (tester) async {
      final initialUrls = [
        'https://example.com/pic1.webp',
        'https://example.com/pic2.webp',
      ];
      List<String> currentUrls = List.from(initialUrls);

      await tester.pumpWidget(
        wrapWithTheme(
          AppMultiImagePicker(
            initialUrls: initialUrls,
            maxImages: 4,
            label: 'Photos',
            onUrlsChanged: (urls) {
              currentUrls = urls;
            },
          ),
        ),
      );

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
      expect(find.text('Add Photo'), findsOneWidget);

      // Verify removal
      final closeIcons = find.byIcon(Icons.close_rounded);
      expect(closeIcons, findsNWidgets(2));

      await tester.tap(closeIcons.first);
      await tester.pumpAndSettle();

      expect(currentUrls.length, 1);
      expect(currentUrls.first, 'https://example.com/pic2.webp');
      expect(find.text('1/4'), findsOneWidget);
    });
  });
}

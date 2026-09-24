import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aaspaas/core/theme/app_icons.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/shared/widgets/avatars/app_avatar.dart';
import 'package:aaspaas/shared/widgets/buttons/app_button.dart';
import 'package:aaspaas/shared/widgets/cards/app_card.dart';
import 'package:aaspaas/shared/widgets/chips/app_badge.dart';
import 'package:aaspaas/shared/widgets/chips/app_chip.dart';
import 'package:aaspaas/shared/widgets/feedback/app_empty_state.dart';
import 'package:aaspaas/shared/widgets/feedback/app_error_state.dart';
import 'package:aaspaas/shared/widgets/feedback/app_skeleton.dart';
import 'package:aaspaas/shared/widgets/inputs/app_search_bar.dart';
import 'package:aaspaas/shared/widgets/inputs/app_text_field.dart';

Widget _buildTestApp(Widget child, {bool isDark = false}) {
  return MaterialApp(
    theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('renders button text and triggers onPressed', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        _buildTestApp(
          AppButton(
            text: 'Click Me',
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      await tester.tap(find.text('Click Me'));
      expect(pressed, isTrue);
    });

    testWidgets('disabled button does not trigger onPressed', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        _buildTestApp(
          const AppButton(
            text: 'Disabled Button',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(find.text('Disabled Button'));
      expect(pressed, isFalse);
    });

    testWidgets(
        'loading state displays CircularProgressIndicator and disables tap',
        (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        _buildTestApp(
          AppButton(
            text: 'Saving...',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving...'), findsNothing);

      await tester.tap(find.byType(CircularProgressIndicator));
      expect(pressed, isFalse);
    });

    testWidgets('renders prefix and suffix icons', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          AppButton(
            text: 'With Icons',
            prefixIcon: AppIcons.check,
            suffixIcon: AppIcons.forward,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(AppIcons.check), findsOneWidget);
      expect(find.byIcon(AppIcons.forward), findsOneWidget);
      expect(find.text('With Icons'), findsOneWidget);
    });
  });

  group('AppCard', () {
    testWidgets('renders card content with proper structure', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AppCard(
            child: Text('Card Content'),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('interactive card triggers onTap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          AppCard(
            onTap: () => tapped = true,
            child: const Text('Tappable Card'),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Card'));
      expect(tapped, isTrue);
    });
  });

  group('AppAvatar', () {
    testWidgets('generates initials from full name', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AppAvatar(
            name: 'Priya Sharma',
            size: AppAvatarSize.s48,
          ),
        ),
      );

      expect(find.text('PS'), findsOneWidget);
    });

    testWidgets('shows fallback icon when name is empty or null',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AppAvatar(size: AppAvatarSize.s40),
        ),
      );

      expect(find.byIcon(AppIcons.profile), findsOneWidget);
    });
  });

  group('AppChip & AppBadge', () {
    testWidgets('AppChip triggers onSelected callback', (tester) async {
      var selected = false;

      await tester.pumpWidget(
        _buildTestApp(
          AppChip(
            label: 'Announcements',
            isSelected: false,
            onSelected: (val) => selected = val,
          ),
        ),
      );

      expect(find.text('Announcements'), findsOneWidget);
      await tester.tap(find.text('Announcements'));
      expect(selected, isTrue);
    });

    testWidgets('AppBadge displays label and variant styling', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AppBadge(
            label: 'Verified',
            variant: AppBadgeVariant.success,
            icon: AppIcons.checkCircle,
          ),
        ),
      );

      expect(find.text('Verified'), findsOneWidget);
      expect(find.byIcon(AppIcons.checkCircle), findsOneWidget);
    });
  });

  group('AppTextField & AppSearchBar', () {
    testWidgets('AppTextField accepts input and shows label & hint',
        (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        _buildTestApp(
          AppTextField(
            controller: controller,
            label: 'Community Name',
            hint: 'Enter name',
          ),
        ),
      );

      expect(find.text('Community Name'), findsOneWidget);
      expect(find.text('Enter name'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Local Resident Club',
      );
      expect(controller.text, 'Local Resident Club');
    });

    testWidgets('AppTextField displays error message when errorText is present',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AppTextField(
            label: 'Email',
            errorText: 'Invalid email address',
          ),
        ),
      );

      expect(find.text('Invalid email address'), findsOneWidget);
    });

    testWidgets('AppSearchBar displays hint and responds to tap',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          AppSearchBar(
            hint: 'Search...',
            onTap: () => tapped = true,
            readOnly: true,
          ),
        ),
      );

      expect(find.text('Search...'), findsOneWidget);
      await tester.tap(find.byType(AppSearchBar));
      expect(tapped, isTrue);
    });
  });

  group('AppEmptyState & AppErrorState', () {
    testWidgets('AppEmptyState displays title, description and triggers action',
        (tester) async {
      var actionTriggered = false;

      await tester.pumpWidget(
        _buildTestApp(
          AppEmptyState(
            icon: AppIcons.communities,
            title: 'No Communities Yet',
            description: 'Join or create a community to start engaging.',
            actionText: 'Explore',
            onAction: () => actionTriggered = true,
          ),
        ),
      );

      expect(find.text('No Communities Yet'), findsOneWidget);
      expect(
        find.text('Join or create a community to start engaging.'),
        findsOneWidget,
      );
      expect(find.text('Explore'), findsOneWidget);

      await tester.tap(find.text('Explore'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('AppErrorState displays message and triggers retry action',
        (tester) async {
      var retried = false;

      await tester.pumpWidget(
        _buildTestApp(
          AppErrorState(
            title: 'Connection Failed',
            message: 'Unable to reach the local gateway.',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Connection Failed'), findsOneWidget);
      expect(find.text('Unable to reach the local gateway.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('AppSkeleton', () {
    testWidgets('renders skeleton shape', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AppSkeleton(width: 120, height: 20),
        ),
      );

      expect(find.byType(AppSkeleton), findsOneWidget);
    });
  });
}

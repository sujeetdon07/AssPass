import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../messaging/application/conversations_controller.dart';
import '../../../notifications/presentation/widgets/notification_badge.dart';

/// The root application shell with top identity header and bottom navigation.
class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({
    required this.navigationShell,
    this.branchNavigatorKeys = const [],
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentIndex = navigationShell.currentIndex;
    final currentBranchKey = currentIndex < branchNavigatorKeys.length
        ? branchNavigatorKeys[currentIndex]
        : null;

    final canBranchPop = currentBranchKey?.currentState?.canPop() ?? false;
    final isHomeBranch = currentIndex == 0;
    final canPop = isHomeBranch && !canBranchPop;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Step 1: Check whether root navigator can pop (dialogs/modals on root)
        if (rootNavigatorKey.currentState?.canPop() ?? false) {
          rootNavigatorKey.currentState!.pop();
          return;
        }

        // Step 2: Check whether current branch navigator contains a child route or modal
        if (currentBranchKey?.currentState?.canPop() ?? false) {
          currentBranchKey!.currentState!.pop();
          return;
        }

        // Step 3: If current branch is at its root and NOT Home, switch to Home branch
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return;
        }
      },
      child: Scaffold(
        appBar: _buildHeader(context, ref, isDark),
        body: navigationShell,
        bottomNavigationBar: _buildBottomNav(context, isDark),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final authState = ref.watch(authControllerProvider);
    final localityText = authState is AuthAuthenticated
        ? authState.user.localitySummary
        : 'Aaspaas';

    return AppBar(
      titleSpacing: AppSpacing.sm,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aaspaas Logo Treatment
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.indigo600, AppColors.violet600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.borderSm,
            ),
            child: const Center(
              child: Text(
                'आ',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          AppSpacing.gapHXs,
          Text(
            'Aaspaas',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.pureWhite : AppColors.slate900,
              letterSpacing: -0.5,
            ),
          ),
          AppSpacing.gapHXs,

          // Locality / Neighborhood Pill
          Flexible(
            child: InkWell(
              onTap: () {
                AppSnackbar.showInfo(
                  context,
                  message: 'Your feed is personalized to your locality.',
                );
              },
              borderRadius: AppRadius.chip,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerHigh
                      : AppColors.lightSurfaceContainer,
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.location,
                      size: 13,
                      color:
                          isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    ),
                    AppSpacing.gapHXxs,
                    Flexible(
                      child: Text(
                        localityText,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Quick Theme Toggle
        AppIconButton(
          icon: isDark ? AppIcons.lightMode : AppIcons.darkMode,
          semanticLabel: 'Toggle theme mode',
          iconSize: 20,
          minTouchTarget: 36.0,
          onPressed: () {
            ref.read(themeModeProvider.notifier).toggleTheme();
          },
        ),

        // Messages with unread badge counter
        Consumer(
          builder: (context, ref, _) {
            final unreadCount = ref.watch(totalUnreadMessagesProvider);
            return Stack(
              alignment: Alignment.center,
              children: [
                AppIconButton(
                  icon: AppIcons.comment,
                  semanticLabel: 'Messages',
                  iconSize: 21,
                  minTouchTarget: 36.0,
                  onPressed: () {
                    context.push('/messages');
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.rose500,
                        borderRadius: AppRadius.borderPill,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // Notifications Center Button with Live Badge
        NotificationBadge(
          minTouchTarget: 36.0,
          onPressed: () {
            context.push(AppRoutes.notifications);
          },
        ),

        // Profile Avatar
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: GestureDetector(
            onTap: () => navigationShell.goBranch(4),
            child: AppAvatar(
              name: ref.watch(authControllerProvider) is AuthAuthenticated
                  ? (ref.watch(authControllerProvider) as AuthAuthenticated)
                      .user
                      .displayName
                  : null,
              imageUrl: ref.watch(authControllerProvider) is AuthAuthenticated
                  ? (ref.watch(authControllerProvider) as AuthAuthenticated)
                      .user
                      .avatarUrl
                  : null,
              size: AppAvatarSize.s32,
              semanticLabel: 'Profile',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    return NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) {
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(AppIcons.homeOutline),
          selectedIcon: Icon(AppIcons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.nearbyOutline),
          selectedIcon: Icon(AppIcons.nearby),
          label: 'Nearby',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.communitiesOutline),
          selectedIcon: Icon(AppIcons.communities),
          label: 'Communities',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.marketplaceOutline),
          selectedIcon: Icon(AppIcons.marketplace),
          label: 'Marketplace',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.profileOutline),
          selectedIcon: Icon(AppIcons.profile),
          label: 'Profile',
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// The root application shell with top identity header and bottom navigation.
class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildHeader(context, ref, isDark),
      body: navigationShell,
      bottomNavigationBar: _buildBottomNav(context, isDark),
    );
  }

  PreferredSizeWidget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    return AppBar(
      titleSpacing: AppSpacing.md,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      title: Row(
        children: [
          // Aaspaas Logo Treatment
          Container(
            width: 32,
            height: 32,
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          AppSpacing.gapHSm,
          Text(
            'Aaspaas',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.pureWhite : AppColors.slate900,
              letterSpacing: -0.5,
            ),
          ),
          AppSpacing.gapHSm,

          // Locality / Neighborhood Pill
          InkWell(
            onTap: () {
              AppSnackbar.showInfo(
                context,
                message: 'Your feed is personalized to your locality.',
              );
            },
            borderRadius: AppRadius.chip,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerHigh
                    : AppColors.lightSurfaceContainer,
                borderRadius: AppRadius.chip,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.location,
                    size: 14,
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                  AppSpacing.gapHXxs,
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      ref.watch(authControllerProvider) is AuthAuthenticated
                          ? (ref.watch(authControllerProvider)
                                  as AuthAuthenticated)
                              .user
                              .localitySummary
                          : 'Aaspaas',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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
          onPressed: () {
            ref.read(themeModeProvider.notifier).toggleTheme();
          },
        ),

        // Notifications Placeholder
        AppIconButton(
          icon: AppIcons.notificationsOutline,
          semanticLabel: 'Notifications',
          iconSize: 22,
          onPressed: () {
            AppSnackbar.showInfo(
              context,
              message: 'Notifications will be available in future phases.',
            );
          },
        ),

        // Profile Avatar
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
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

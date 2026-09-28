import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
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
import '../../../nearby/application/location_controller.dart';
import '../../../nearby/domain/entities/location_state.dart';
import '../../../nearby/presentation/widgets/locality_picker_dialog.dart';
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
    final locationState = ref.watch(locationControllerProvider);
    final localityText = locationState is LocationManualLocality
        ? locationState.localityName
        : (authState is AuthAuthenticated
            ? authState.user.localitySummary
            : 'Indiranagar');

    return AppBar(
      titleSpacing: AppSpacing.sm,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.8),
        child: Container(
          color: isDark
              ? AppColors.darkOutlineVariant
              : AppColors.lightOutlineVariant,
          height: 0.8,
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aaspaas Logo Treatment
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x304F46E5),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'आ',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Aaspaas',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16.5,
              color: isDark ? AppColors.pureWhite : AppColors.slate900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 5),

          // Locality / Neighborhood Pill
          Flexible(
            child: InkWell(
              onTap: () async {
                final result = await LocalityPickerDialog.show(context);
                if (result != null && context.mounted) {
                  ref.read(locationControllerProvider.notifier).setManualLocality(
                        localityName: result.locality,
                        cityName: result.city,
                        latitude: result.lat,
                        longitude: result.lng,
                      );
                  AppSnackbar.showSuccess(
                    context,
                    message: 'Location updated to ${result.locality}',
                  );
                }
              },
              borderRadius: AppRadius.chip,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E284A)
                      : const Color(0xFFF1F3FB),
                  borderRadius: AppRadius.chip,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2C3B66)
                        : const Color(0xFFD6DBFC),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.location,
                      size: 13,
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        localityText,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextPrimary,
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
          minTouchTarget: 32.0,
          color: isDark ? AppColors.amber500 : const Color(0xFF152242),
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
                  iconSize: 20,
                  minTouchTarget: 32.0,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : const Color(0xFF152242),
                  onPressed: () {
                    context.push('/messages');
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.rose500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // Notifications Center Button with Live Badge
        NotificationBadge(
          iconSize: 20.0,
          minTouchTarget: 32.0,
          dotOnly: true,
          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF152242),
          onPressed: () {
            context.push(AppRoutes.notifications);
          },
        ),

        // Profile Avatar
        Padding(
          padding: const EdgeInsets.only(left: 2, right: AppSpacing.sm),
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        boxShadow: AppElevation.shadowBar,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkOutlineVariant
                : AppColors.lightOutlineVariant,
            width: 0.8,
          ),
        ),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 64,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          surfaceTintColor: AppColors.transparent,
          elevation: AppElevation.none,
          indicatorColor: isDark
              ? const Color(0xFF1E284A)
              : const Color(0xFFEEF0FF),
          indicatorShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: isSelected ? 10.5 : 10.0,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: -0.35,
              height: 1.2,
              color: isSelected
                  ? (isDark ? AppColors.indigo300 : AppColors.indigo600)
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.slate500),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 22,
              color: isSelected
                  ? (isDark ? AppColors.indigo300 : AppColors.indigo600)
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.slate500),
            );
          }),
        ),
        child: NavigationBar(
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
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/services/app_share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/chips/app_badge.dart';
import '../../../../shared/widgets/chips/app_chip.dart';
import '../../../../shared/widgets/feedback/app_dialog.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';

/// Profile screen displaying authenticated user identity, locality badge,
/// theme switcher, and logout functionality.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.show(
      context,
      title: 'Log Out',
      message: 'Are you sure you want to log out of Aaspaas on this device?',
      confirmText: 'Log Out',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: AppIcons.logout,
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) {
        AppSnackbar.showInfo(
          context,
          message: 'You have been logged out.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authControllerProvider);

    final user = authState is AuthAuthenticated
        ? authState.user
        : (authState is AuthOnboardingRequired ? authState.user : null);

    final displayName = user?.displayName ?? 'Neighbor';
    final locality = user?.localitySummary ?? 'No locality selected';

    return Scaffold(
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              AppSpacing.gapVSm,

              // Authenticated User Profile Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AppAvatar(
                          imageUrl: user?.avatarUrl,
                          name: displayName,
                          size: AppAvatarSize.s48,
                          semanticLabel: 'Neighbor avatar',
                        ),
                        AppSpacing.gapHMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (user?.isPhoneVerified ?? true) ...[
                                    AppSpacing.gapHXs,
                                    const Icon(
                                      AppIcons.checkCircle,
                                      size: 16,
                                      color: AppColors.emerald500,
                                    ),
                                  ],
                                ],
                              ),
                              if (user?.handle != null) ...[
                                AppSpacing.gapVXs,
                                Text(
                                  user!.handle!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.darkPrimary
                                        : AppColors.lightPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                AppSpacing.gapVXs,
                                GestureDetector(
                                  onTap: () => context.push(AppRoutes.editProfile),
                                  child: Text(
                                    '+ Set @username',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.indigo300
                                          : AppColors.indigo600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              AppSpacing.gapVXs,
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.location,
                                    size: 14,
                                    color: isDark
                                        ? AppColors.darkPrimary
                                        : AppColors.lightPrimary,
                                  ),
                                  AppSpacing.gapHXs,
                                  Flexible(
                                    child: Text(
                                      locality,
                                      style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapVSm,
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Edit Profile',
                            variant: AppButtonVariant.outlined,
                            prefixIcon: AppIcons.edit,
                            onPressed: () => context.push(AppRoutes.editProfile),
                          ),
                        ),
                        AppSpacing.gapHSm,
                        AppButton(
                          isFullWidth: false,
                          text: 'Share',
                          variant: AppButtonVariant.outlined,
                          prefixIcon: Icons.share_rounded,
                          onPressed: () {
                            if (user != null) {
                              final payload = AppShareService.buildProfilePayload(
                                displayName: user.displayName ?? 'Neighbor',
                                username: user.username,
                                locality: user.localitySummary,
                              );
                              AppShareService.share(context, payload);
                            }
                          },
                        ),
                      ],
                    ),
                    if (user?.neighborhood != null &&
                        user!.neighborhood!.trim().isNotEmpty) ...[
                      AppSpacing.gapVXs,
                      Text(
                        user.neighborhood!.trim(),
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (user?.bio != null && user!.bio!.trim().isNotEmpty) ...[
                      AppSpacing.gapVSm,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                          borderRadius: AppRadius.card,
                        ),
                        child: Text(
                          user.bio!.trim(),
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    AppSpacing.gapVSm,
                    const Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AppBadge(
                          label: 'Phone Verified',
                          variant: AppBadgeVariant.success,
                          icon: AppIcons.verified,
                        ),
                        AppBadge(
                          label: 'Resident Member',
                          variant: AppBadgeVariant.neutral,
                          icon: AppIcons.home,
                        ),
                        AppBadge(
                          label: 'Preview Profile',
                          variant: AppBadgeVariant.neutral,
                          icon: AppIcons.info,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              AppSpacing.gapVSm,

              // Theme Mode Setting Card (Preserved from Phase 1)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isDark ? AppIcons.darkMode : AppIcons.lightMode,
                          size: 20,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                        AppSpacing.gapHSm,
                        Expanded(
                          child: Text(
                            'Theme Mode',
                            style: AppTypography.titleMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapVXs,
                    Text(
                      'Choose whether Aaspaas follows your system preference or uses a fixed light or dark theme.',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    AppSpacing.gapVSm,
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppChip(
                          label: 'System',
                          icon: AppIcons.systemMode,
                          isSelected: currentThemeMode == ThemeMode.system,
                          onSelected: (_) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.system);
                            AppSnackbar.showInfo(
                              context,
                              message: 'Theme set to System default.',
                            );
                          },
                        ),
                        AppChip(
                          label: 'Light',
                          icon: AppIcons.lightMode,
                          isSelected: currentThemeMode == ThemeMode.light,
                          onSelected: (_) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.light);
                            AppSnackbar.showInfo(
                              context,
                              message: 'Theme set to Light mode.',
                            );
                          },
                        ),
                        AppChip(
                          label: 'Dark',
                          icon: AppIcons.darkMode,
                          isSelected: currentThemeMode == ThemeMode.dark,
                          onSelected: (_) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.dark);
                            AppSnackbar.showInfo(
                              context,
                              message: 'Theme set to Dark mode.',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              AppSpacing.gapVMd,

              // ── Businesses & Services Management Card ─────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          AppIcons.business,
                          size: 20,
                          color: AppColors.indigo600,
                        ),
                        AppSpacing.gapHSm,
                        Expanded(
                          child: Text(
                            'My Listings & Services',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapVXs,
                    Text(
                      'Manage your local shop listings, trades, and service offerings.',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    AppSpacing.gapVMd,
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: AppRadius.card,
                        onTap: () => context.push('/businesses/my-businesses'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: AppColors.indigo600
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  AppIcons.business,
                                  size: 20,
                                  color: AppColors.indigo600,
                                ),
                              ),
                              AppSpacing.gapHSm,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'My Businesses',
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      'View and edit your registered shops',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(AppIcons.chevronRight, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: AppRadius.card,
                        onTap: () => context.push('/services/my-services'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald500
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  AppIcons.service,
                                  size: 20,
                                  color: AppColors.emerald500,
                                ),
                              ),
                              AppSpacing.gapHSm,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'My Services',
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Manage your service listings & rates',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(AppIcons.chevronRight, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.gapVMd,

              // ── Privacy & Safety Card ──────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          AppIcons.verifiedShield,
                          size: 20,
                          color: AppColors.teal600,
                        ),
                        AppSpacing.gapHSm,
                        Expanded(
                          child: Text(
                            'Privacy & Safety',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapVXs,
                    Text(
                      'Manage your safety preferences, blocked contacts, and community guidelines.',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    AppSpacing.gapVMd,
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: AppRadius.card,
                        onTap: () => context.push(AppRoutes.blockedUsers),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: AppColors.rose500
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.block_outlined,
                                  size: 20,
                                  color: AppColors.rose500,
                                ),
                              ),
                              AppSpacing.gapHSm,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Blocked Users',
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      'View and unblock accounts you have blocked',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(AppIcons.chevronRight, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: AppRadius.card,
                        onTap: () => context.push(AppRoutes.reportHistory),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: AppColors.indigo600
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.history_rounded,
                                  size: 20,
                                  color: AppColors.indigo600,
                                ),
                              ),
                              AppSpacing.gapHSm,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Report History',
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Track the status of safety reports you submitted',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(AppIcons.chevronRight, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.gapVMd,

              // Account & Session Management Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account & Security',
                      style: AppTypography.titleMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    AppSpacing.gapVXs,
                    Text(
                      'Log out of your current session on this device. Your account and locality settings remain securely stored.',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    AppSpacing.gapVLg,
                    AppButton(
                      text: 'Log Out',
                      variant: AppButtonVariant.destructive,
                      prefixIcon: AppIcons.logout,
                      onPressed: () => _handleLogout(context, ref),
                    ),
                  ],
                ),
              ),

              AppSpacing.gapVMd,
            ],
          ),
        ),
      ),
    );
  }
}

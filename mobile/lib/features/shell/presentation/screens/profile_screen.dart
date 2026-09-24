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
    final maskedPhone = user?.phoneNumber ?? '';
    final locality = user?.localitySummary ?? 'No locality selected';

    return Scaffold(
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              AppSpacing.gapVMd,

              // Authenticated User Profile Card
              AppCard(
                child: Column(
                  children: [
                    const AppAvatar(
                      size: AppAvatarSize.s72,
                      semanticLabel: 'Neighbor avatar',
                    ),
                    AppSpacing.gapVMd,
                    Text(
                      displayName,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (maskedPhone.isNotEmpty) ...[
                      AppSpacing.gapVXs,
                      Text(
                        maskedPhone,
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                    AppSpacing.gapVXs,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.location,
                          size: 14,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                        AppSpacing.gapHXs,
                        Text(
                          locality,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapVMd,
                    const Wrap(
                      spacing: 8,
                      children: [
                        AppBadge(
                          label: 'Active Member',
                          variant: AppBadgeVariant.success,
                          icon: AppIcons.verified,
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

              AppSpacing.gapVMd,

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
                        Text(
                          'Theme Mode',
                          style: AppTypography.titleMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
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
                    AppSpacing.gapVMd,
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
                        Text(
                          'My Listings & Services',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
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

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

enum AppBadgeVariant {
  primary,
  success,
  warning,
  error,
  neutral,
}

/// Compact badge for numerical counts, categories, and status indicators.
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    super.key,
    this.variant = AppBadgeVariant.primary,
    this.icon,
  });

  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (bg, fg) = _resolveColors(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            AppSpacing.gapHXs,
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _resolveColors(bool isDark) {
    return switch (variant) {
      AppBadgeVariant.primary => (
          isDark
              ? AppColors.darkPrimaryContainer
              : AppColors.lightPrimaryContainer,
          isDark
              ? AppColors.darkOnPrimaryContainer
              : AppColors.lightOnPrimaryContainer,
        ),
      AppBadgeVariant.success => (
          isDark
              ? AppColors.darkSuccessContainer
              : AppColors.lightSuccessContainer,
          isDark
              ? AppColors.darkOnSuccessContainer
              : AppColors.lightOnSuccessContainer,
        ),
      AppBadgeVariant.warning => (
          isDark
              ? AppColors.darkWarningContainer
              : AppColors.lightWarningContainer,
          isDark
              ? AppColors.darkOnWarningContainer
              : AppColors.lightOnWarningContainer,
        ),
      AppBadgeVariant.error => (
          isDark ? AppColors.darkErrorContainer : AppColors.lightErrorContainer,
          isDark
              ? AppColors.darkOnErrorContainer
              : AppColors.lightOnErrorContainer,
        ),
      AppBadgeVariant.neutral => (
          isDark
              ? AppColors.darkSurfaceContainerHigh
              : AppColors.lightSurfaceContainerHigh,
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
    };
  }
}

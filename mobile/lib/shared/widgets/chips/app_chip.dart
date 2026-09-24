import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

enum AppChipVariant {
  standard,
  statusSuccess,
  statusWarning,
  statusError,
  statusInfo,
}

/// Token-driven chip component supporting filter, action, and status modes.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    super.key,
    this.isSelected = false,
    this.isEnabled = true,
    this.icon,
    this.onSelected,
    this.onDeleted,
    this.variant = AppChipVariant.standard,
  });

  final String label;
  final bool isSelected;
  final bool isEnabled;
  final IconData? icon;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onDeleted;
  final AppChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final colors = _resolveColors(isDark);

    Widget? leadingIcon;
    if (icon != null) {
      leadingIcon = Icon(icon, size: 16, color: colors.foreground);
    }

    Widget? deleteIcon;
    if (onDeleted != null) {
      deleteIcon = GestureDetector(
        onTap: isEnabled ? onDeleted : null,
        child: Icon(Icons.close_rounded, size: 16, color: colors.foreground),
      );
    }

    return FilterChip(
      label: Text(
        label,
        style: AppTypography.labelMedium.copyWith(color: colors.foreground),
      ),
      selected: isSelected,
      onSelected: isEnabled ? onSelected : null,
      avatar: leadingIcon,
      deleteIcon: deleteIcon,
      onDeleted: isEnabled ? onDeleted : null,
      backgroundColor: colors.background,
      selectedColor: colors.selectedBackground,
      disabledColor: colors.disabledBackground,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.chip,
        side: BorderSide(
          color: colors.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  _ChipColors _resolveColors(bool isDark) {
    if (!isEnabled) {
      return _ChipColors(
        background: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLow,
        selectedBackground: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLow,
        disabledBackground: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLow,
        foreground:
            isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
        border: isDark
            ? AppColors.darkOutlineVariant
            : AppColors.lightOutlineVariant,
      );
    }

    switch (variant) {
      case AppChipVariant.standard:
        return _ChipColors(
          background: isDark
              ? AppColors.darkSurfaceContainer
              : AppColors.lightSurfaceContainer,
          selectedBackground: isDark
              ? AppColors.darkPrimaryContainer
              : AppColors.lightPrimaryContainer,
          disabledBackground: isDark
              ? AppColors.darkSurfaceContainerLow
              : AppColors.lightSurfaceContainerLow,
          foreground: isSelected
              ? (isDark
                  ? AppColors.darkOnPrimaryContainer
                  : AppColors.lightOnPrimaryContainer)
              : (isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary),
          border: isSelected
              ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
              : (isDark
                  ? AppColors.darkOutlineVariant
                  : AppColors.lightOutlineVariant),
        );

      case AppChipVariant.statusSuccess:
        return _ChipColors(
          background: isDark
              ? AppColors.darkSuccessContainer
              : AppColors.lightSuccessContainer,
          selectedBackground: isDark
              ? AppColors.darkSuccessContainer
              : AppColors.lightSuccessContainer,
          disabledBackground: AppColors.transparent,
          foreground: isDark
              ? AppColors.darkOnSuccessContainer
              : AppColors.lightOnSuccessContainer,
          border: AppColors.transparent,
        );

      case AppChipVariant.statusWarning:
        return _ChipColors(
          background: isDark
              ? AppColors.darkWarningContainer
              : AppColors.lightWarningContainer,
          selectedBackground: isDark
              ? AppColors.darkWarningContainer
              : AppColors.lightWarningContainer,
          disabledBackground: AppColors.transparent,
          foreground: isDark
              ? AppColors.darkOnWarningContainer
              : AppColors.lightOnWarningContainer,
          border: AppColors.transparent,
        );

      case AppChipVariant.statusError:
        return _ChipColors(
          background: isDark
              ? AppColors.darkErrorContainer
              : AppColors.lightErrorContainer,
          selectedBackground: isDark
              ? AppColors.darkErrorContainer
              : AppColors.lightErrorContainer,
          disabledBackground: AppColors.transparent,
          foreground: isDark
              ? AppColors.darkOnErrorContainer
              : AppColors.lightOnErrorContainer,
          border: AppColors.transparent,
        );

      case AppChipVariant.statusInfo:
        return _ChipColors(
          background: isDark
              ? AppColors.darkInfoContainer
              : AppColors.lightInfoContainer,
          selectedBackground: isDark
              ? AppColors.darkInfoContainer
              : AppColors.lightInfoContainer,
          disabledBackground: AppColors.transparent,
          foreground: isDark
              ? AppColors.darkOnInfoContainer
              : AppColors.lightOnInfoContainer,
          border: AppColors.transparent,
        );
    }
  }
}

class _ChipColors {
  const _ChipColors({
    required this.background,
    required this.selectedBackground,
    required this.disabledBackground,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color selectedBackground;
  final Color disabledBackground;
  final Color foreground;
  final Color border;
}

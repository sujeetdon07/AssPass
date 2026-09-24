import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/app_button.dart';

/// Reusable confirmation and informational dialog.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.message,
    super.key,
    this.icon,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    IconData? icon,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        icon: icon,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.none,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.none,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 24,
              color: isDestructive
                  ? (isDark ? AppColors.darkError : AppColors.lightError)
                  : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
            ),
            AppSpacing.gapHSm,
          ],
          Expanded(
            child: Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (onCancel != null) ...[
              TextButton(
                onPressed: onCancel,
                child: Text(
                  cancelText,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              AppSpacing.gapHSm,
            ],
            if (onConfirm != null)
              AppButton(
                text: confirmText,
                onPressed: onConfirm,
                variant: isDestructive
                    ? AppButtonVariant.destructive
                    : AppButtonVariant.primary,
                isFullWidth: false,
              ),
          ],
        ),
      ],
    );
  }
}

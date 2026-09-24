import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Reusable text button component.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    required this.text,
    required this.onPressed,
    super.key,
    this.icon,
    this.textColor,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final resolvedColor =
        textColor ?? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary);

    Widget child;
    if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: resolvedColor),
          AppSpacing.gapHSm,
          Text(
            text,
            style: AppTypography.labelLarge.copyWith(color: resolvedColor),
          ),
        ],
      );
    } else {
      child = Text(
        text,
        style: AppTypography.labelLarge.copyWith(color: resolvedColor),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: resolvedColor,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      child: child,
    );
  }
}

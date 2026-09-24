import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Hairline divider with optional text separator label.
class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.label,
    this.verticalMargin = AppSpacing.md,
  });

  final String? label;
  final double verticalMargin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final lineColor =
        isDark ? AppColors.darkOutlineVariant : AppColors.lightOutlineVariant;

    if (label == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: verticalMargin),
        child: Divider(
          color: lineColor,
          thickness: 1,
          height: 1,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalMargin),
      child: Row(
        children: [
          Expanded(child: Divider(color: lineColor, thickness: 1, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label!,
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ),
          Expanded(child: Divider(color: lineColor, thickness: 1, height: 1)),
        ],
      ),
    );
  }
}

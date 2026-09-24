import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

const List<int> kRadiusOptions = [1, 3, 5, 10, 20];

/// Material 3 radius selector chips for Nearby discovery.
class RadiusSelector extends StatelessWidget {
  const RadiusSelector({
    super.key,
    required this.selectedRadiusKm,
    required this.onRadiusSelected,
  });

  final int selectedRadiusKm;
  final ValueChanged<int> onRadiusSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: kRadiusOptions.map((radius) {
          final isSelected = radius == selectedRadiusKm;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onRadiusSelected(radius),
                borderRadius: AppRadius.chip,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : (isDark
                            ? AppColors.darkSurfaceContainerHigh
                            : AppColors.lightSurfaceContainer),
                    borderRadius: AppRadius.chip,
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isDark
                              ? AppColors.darkOutline
                              : AppColors.lightOutline),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$radius km',
                        style: AppTypography.labelMedium.copyWith(
                          color: isSelected
                              ? AppColors.pureWhite
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

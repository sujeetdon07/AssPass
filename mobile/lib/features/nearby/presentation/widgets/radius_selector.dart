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
                        ? (isDark ? AppColors.indigo950 : const Color(0xFFEEF0FF))
                        : (isDark
                            ? AppColors.darkSurfaceContainer
                            : AppColors.pureWhite),
                    borderRadius: AppRadius.chip,
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? AppColors.indigo500 : const Color(0xFFC7D2FE))
                          : (isDark
                              ? AppColors.darkOutlineVariant
                              : AppColors.lightOutlineVariant),
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
                              ? (isDark ? AppColors.indigo300 : const Color(0xFF4338CA))
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
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

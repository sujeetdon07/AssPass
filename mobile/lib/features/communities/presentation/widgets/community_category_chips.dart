import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/chips/app_chip.dart';
import '../../domain/entities/community_category.dart';

/// Horizontal scrollable bar of category chips for filtering communities.
class CommunityCategoryChips extends StatelessWidget {
  const CommunityCategoryChips({
    required this.selectedCategory,
    required this.onCategorySelected,
    super.key,
  });

  final CommunityCategory? selectedCategory;
  final ValueChanged<CommunityCategory?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // "All" Chip
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppChip(
              label: 'All',
              icon: AppIcons.communities,
              isSelected: selectedCategory == null,
              onSelected: (_) => onCategorySelected(null),
            ),
          ),

          // Individual Categories
          ...CommunityCategory.values.map((cat) {
            final isSelected = selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: AppChip(
                label: cat.label,
                icon: cat.icon,
                isSelected: isSelected,
                onSelected: (_) {
                  onCategorySelected(isSelected ? null : cat);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

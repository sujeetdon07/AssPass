import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/marketplace_status.dart';

/// Pill badge displaying listing status (Active, Sold, Archived).
class ListingStatusChip extends StatelessWidget {
  const ListingStatusChip({
    super.key,
    required this.status,
  });

  final MarketplaceListingStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case MarketplaceListingStatus.active:
        bg = AppColors.emerald50;
        fg = AppColors.emerald700;
      case MarketplaceListingStatus.sold:
        bg = AppColors.slate200;
        fg = AppColors.slate700;
      case MarketplaceListingStatus.archived:
        bg = AppColors.amber50;
        fg = AppColors.amber700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderPill,
      ),
      child: Text(
        status.label,
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

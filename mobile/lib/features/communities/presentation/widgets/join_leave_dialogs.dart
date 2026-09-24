import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Confirmation dialog for leaving a community.
Future<bool?> showLeaveCommunityDialog(
  BuildContext context, {
  required String communityName,
  required bool isPrivate,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        'Leave $communityName?',
        style: AppTypography.titleMedium.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        isPrivate
            ? 'This is a private community. If you leave, you will lose access to all posts and discussions until you join again.'
            : 'Are you sure you want to leave this community? You can rejoin at any time.',
        style: AppTypography.bodyMedium.copyWith(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor:
                isDark ? AppColors.darkError : AppColors.lightError,
            foregroundColor: AppColors.pureWhite,
          ),
          child: const Text('Leave Community'),
        ),
      ],
    ),
  );
}

/// Alert dialog when community owner tries to leave.
Future<void> showOwnerCannotLeaveDialog(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cannot Leave Community'),
      content: Text(
        'As the owner and creator of this community, you cannot leave it. You must manage or archive it from settings.',
        style: AppTypography.bodyMedium.copyWith(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

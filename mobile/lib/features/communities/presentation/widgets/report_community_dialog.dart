import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';

/// Interactive reporting dialog for community trust & safety moderation.
Future<bool?> showReportCommunityDialog(
  BuildContext context, {
  required String communityName,
  required Future<bool> Function(String reason, String? details) onSubmit,
}) {
  final reasons = [
    {'key': 'spam', 'label': 'Spam or unsolicited advertising'},
    {'key': 'harassment', 'label': 'Harassment, hate speech, or abuse'},
    {'key': 'misinformation', 'label': 'Misleading or false local information'},
    {'key': 'inappropriate', 'label': 'Inappropriate or illegal content'},
    {'key': 'other', 'label': 'Other community guideline violation'},
  ];

  String selectedReason = 'spam';
  final detailsController = TextEditingController();
  bool isSubmitting = false;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          title: Text(
            'Report $communityName',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help us understand why you are reporting this community:',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                AppSpacing.gapVSm,
                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (val) {
                    if (val != null) setState(() => selectedReason = val);
                  },
                  child: Column(
                    children: reasons.map((r) {
                      return RadioListTile<String>(
                        title: Text(
                          r['label']!,
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        value: r['key']!,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      );
                    }).toList(),
                  ),
                ),
                AppSpacing.gapVSm,
                AppTextField(
                  controller: detailsController,
                  label: 'Additional details (optional)',
                  hint: 'Describe the issue...',
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setState(() => isSubmitting = true);
                      final success = await onSubmit(
                        selectedReason,
                        detailsController.text.trim().isEmpty
                            ? null
                            : detailsController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.of(ctx).pop(success);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.darkError : AppColors.lightError,
                foregroundColor: AppColors.pureWhite,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.pureWhite),
                      ),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        );
      },
    ),
  );
}

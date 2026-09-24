import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/repositories/feed_repository.dart';

enum ReportType { post, comment }

/// Modal dialog for reporting content to the Trust & Safety foundation.
class ReportContentDialog extends ConsumerStatefulWidget {
  const ReportContentDialog({
    required this.targetId,
    required this.targetType,
    super.key,
  });

  final String targetId;
  final ReportType targetType;

  static Future<void> show(
    BuildContext context, {
    required String targetId,
    required ReportType targetType,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ReportContentDialog(
        targetId: targetId,
        targetType: targetType,
      ),
    );
  }

  @override
  ConsumerState<ReportContentDialog> createState() =>
      _ReportContentDialogState();
}

class _ReportContentDialogState extends ConsumerState<ReportContentDialog> {
  String _selectedReason = 'spam';
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final _reasons = const [
    ('spam', 'Spam or commercial advertising'),
    ('harassment', 'Harassment or abusive behavior'),
    ('inappropriate', 'Inappropriate or offensive content'),
    ('misleading', 'Misleading or false information'),
    ('illegal_content', 'Illegal activity or hazardous material'),
    ('other', 'Other concerns'),
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(feedRepositoryProvider);
      if (widget.targetType == ReportType.post) {
        await repository.reportPost(
          postId: widget.targetId,
          reason: _selectedReason,
          details: _detailsController.text.trim(),
        );
      } else {
        await repository.reportComment(
          commentId: widget.targetId,
          reason: _selectedReason,
          details: _detailsController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.showSuccess(
          context,
          message:
              'Thank you for keeping Aaspaas safe. Our moderation team will review this report.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(
          context,
          message:
              'Unable to submit report. You may have already reported this.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text(
        'Report ${widget.targetType == ReportType.post ? 'Post' : 'Comment'}',
        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this ${widget.targetType == ReportType.post ? 'post' : 'comment'}?',
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            AppSpacing.gapVSm,
            ..._reasons.map((reason) {
              final isSelected = _selectedReason == reason.$1;
              return InkWell(
                onTap: () => setState(() => _selectedReason = reason.$1),
                borderRadius: AppRadius.borderSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 20,
                        color: isSelected
                            ? (isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary)
                            : (isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason.$2,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            AppSpacing.gapVSm,
            AppTextField(
              controller: _detailsController,
              label: 'Additional details (optional)',
              hint: 'Provide extra context to help us review...',
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          text: 'Submit Report',
          isLoading: _isSubmitting,
          onPressed: _submitReport,
          isFullWidth: false,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';

/// Modal dialog for reporting a marketplace listing for trust & safety review.
class ReportListingDialog extends StatefulWidget {
  const ReportListingDialog({
    super.key,
    required this.onSubmit,
  });

  final Future<bool> Function(String reason, String? details) onSubmit;

  static Future<bool?> show(
    BuildContext context, {
    required Future<bool> Function(String reason, String? details) onSubmit,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ReportListingDialog(onSubmit: onSubmit),
    );
  }

  @override
  State<ReportListingDialog> createState() => _ReportListingDialogState();
}

class _ReportListingDialogState extends State<ReportListingDialog> {
  String _selectedReason = 'spam';
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  final Map<String, String> _reasons = {
    'spam': 'Spam or Commercial Solicitation',
    'scam': 'Scam, Fraud, or Counterfeit Item',
    'harassment': 'Harassment or Offensive Behavior',
    'inappropriate': 'Inappropriate or Prohibited Item',
    'misinformation': 'Misleading Description or Photos',
    'other': 'Other Community Safety Concern',
  };

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final success = await widget.onSubmit(
      _selectedReason,
      _detailsController.text.trim().isEmpty
          ? null
          : _detailsController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Unable to submit report. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text(
        'Report Listing',
        style: AppTypography.titleMedium.copyWith(
          fontWeight: FontWeight.w700,
          color:
              isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help keep Aaspaas safe for your local neighbors. Why are you reporting this listing?',
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._reasons.entries.map((entry) {
              final isSelected = _selectedReason == entry.key;
              return InkWell(
                onTap: () => setState(() => _selectedReason = entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected
                            ? (isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                hintText: 'Describe what you noticed...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _error!,
                style:
                    AppTypography.labelSmall.copyWith(color: AppColors.rose500),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AppButton(
          text: 'Submit Report',
          isLoading: _isSubmitting,
          isFullWidth: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}

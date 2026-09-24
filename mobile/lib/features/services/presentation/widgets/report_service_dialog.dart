import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';

class ReportServiceDialog extends StatefulWidget {
  const ReportServiceDialog({
    required this.serviceId,
    required this.serviceTitle,
    required this.onSubmit,
    super.key,
  });

  final String serviceId;
  final String serviceTitle;
  final Future<void> Function(String reason, String? details) onSubmit;

  static Future<bool?> show(
    BuildContext context, {
    required String serviceId,
    required String serviceTitle,
    required Future<void> Function(String reason, String? details) onSubmit,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ReportServiceDialog(
        serviceId: serviceId,
        serviceTitle: serviceTitle,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<ReportServiceDialog> createState() => _ReportServiceDialogState();
}

class _ReportServiceDialogState extends State<ReportServiceDialog> {
  String _selectedReason = 'incorrect_info';
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  final Map<String, String> _reasons = {
    'incorrect_info': 'Incorrect pricing or service information',
    'unresponsive': 'Service provider does not respond',
    'fraud_scam': 'Fraud or extortion attempt',
    'spam': 'Spam or irrelevant listing',
    'inappropriate': 'Unprofessional or inappropriate conduct',
    'duplicate': 'Duplicate listing',
    'other': 'Other reason',
  };

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        _selectedReason,
        _detailsController.text.trim().isNotEmpty
            ? _detailsController.text.trim()
            : null,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
      ),
      title: Text(
        'Report Service',
        style: AppTypography.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
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
              'Why are you reporting "${widget.serviceTitle}"?',
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            AppSpacing.gapVSm,
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedReason = val;
                  });
                }
              },
              child: Column(
                children: _reasons.entries.map((entry) {
                  return RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      entry.value,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    value: entry.key,
                  );
                }).toList(),
              ),
            ),
            AppSpacing.gapVSm,
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Additional details (optional)...',
                filled: true,
                fillColor: isDark
                    ? AppColors.darkSurfaceContainer
                    : AppColors.lightSurfaceContainer,
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.borderMd,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              AppSpacing.gapVXs,
              Text(
                _errorMessage!,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.rose500,
                ),
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
          variant: AppButtonVariant.primary,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}

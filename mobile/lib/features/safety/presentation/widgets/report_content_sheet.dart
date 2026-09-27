import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/repositories/safety_repository.dart';
import '../../domain/models/safety_enums.dart';

/// A full-screen bottom sheet for reporting any content, profile, or messaging in Aaspaas.
///
/// Usage:
/// ```dart
/// await ReportContentSheet.show(
///   context,
///   targetId: user.id,
///   targetType: ReportTargetType.user,
/// );
/// ```
class ReportContentSheet extends ConsumerStatefulWidget {
  const ReportContentSheet({
    required this.targetId,
    required this.targetType,
    super.key,
    this.secondaryId,
  });

  final String targetId;
  final ReportTargetType targetType;
  final String? secondaryId;

  /// Shows the report bottom sheet modally. Returns true if report was submitted.
  static Future<bool> show(
    BuildContext context, {
    required String targetId,
    required ReportTargetType targetType,
    String? secondaryId,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportContentSheet(
        targetId: targetId,
        targetType: targetType,
        secondaryId: secondaryId,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends ConsumerState<ReportContentSheet> {
  ReportReason _selectedReason = ReportReason.spam;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  static const _canonicalReasons = [
    ReportReason.spam,
    ReportReason.harassment,
    ReportReason.hateOrAbuse,
    ReportReason.threats,
    ReportReason.scamOrFraud,
    ReportReason.sexualContent,
    ReportReason.violence,
    ReportReason.illegalActivity,
    ReportReason.misinformation,
    ReportReason.impersonation,
    ReportReason.privacyViolation,
    ReportReason.inappropriateContent,
    ReportReason.other,
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read<SafetyRepository>(safetyRepositoryProvider);
      await repo.submitReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _selectedReason,
        details: _detailsController.text.trim(),
        secondaryId: widget.secondaryId,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackbar.showSuccess(
          context,
          message:
              'Thank you for keeping Aaspaas safe. Our moderation team will review this report.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final msg = e.toString().toLowerCase();
        if (msg.contains('already') ||
            msg.contains('409') ||
            msg.contains('duplicate')) {
          Navigator.of(context).pop(false);
          AppSnackbar.showWarning(
            context,
            message:
                'You have already submitted an active report for this content.',
          );
        } else if (msg.contains('429') || msg.contains('too many')) {
          AppSnackbar.showError(
            context,
            message:
                'Too many reports submitted. Please wait before reporting again.',
          );
        } else {
          AppSnackbar.showError(
            context,
            message: 'Unable to submit report. Please try again later.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.darkSurfaceContainerHigh : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkOutline
                        : AppColors.lightOutline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.rose500.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: AppColors.rose500,
                        size: 20,
                      ),
                    ),
                    AppSpacing.gapHSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report ${widget.targetType.label}',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Help us keep Aaspaas safe for everyone',
                            style: AppTypography.bodySmall.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                      iconSize: 22,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      'Why are you reporting this ${widget.targetType.label.toLowerCase()}?',
                      style: AppTypography.labelLarge.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    AppSpacing.gapVSm,

                    // Reason selection list
                    RadioGroup<ReportReason>(
                      groupValue: _selectedReason,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedReason = val);
                      },
                      child: Column(
                        children: _canonicalReasons.map((reason) {
                          final isSelected = _selectedReason == reason;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: AppRadius.borderMd,
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : (isDark
                                        ? AppColors.darkOutlineVariant
                                        : AppColors.lightOutlineVariant),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: RadioListTile<ReportReason>(
                              value: reason,
                              title: Text(
                                reason.label,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: isSelected ? primaryColor : textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              activeColor: primaryColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              dense: true,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    AppSpacing.gapVMd,

                    // Optional details input
                    Text(
                      'Additional details (optional)',
                      style: AppTypography.labelLarge.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    AppSpacing.gapVXs,
                    AppTextField(
                      controller: _detailsController,
                      hint: 'Provide any context that will help our moderation team...',
                      maxLines: 3,
                    ),

                    AppSpacing.gapVLg,

                    // Privacy notice
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainer
                            : AppColors.lightSurfaceContainer,
                        borderRadius: AppRadius.borderMd,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppColors.slate400,
                          ),
                          AppSpacing.gapHSm,
                          Expanded(
                            child: Text(
                              'Reports are completely anonymous to other users. '
                              'The reported party will not know who filed this report.',
                              style: AppTypography.bodySmall.copyWith(
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.gapVLg,

                    // Submit button
                    AppButton(
                      text: 'Submit Report',
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                      variant: AppButtonVariant.primary,
                      isFullWidth: true,
                    ),

                    AppSpacing.gapVLg,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/chips/app_chip.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../application/community_detail_controller.dart';
import '../../domain/entities/community_category.dart';
import '../../domain/entities/community_entity.dart';

/// Screen allowing owners/moderators to edit community details.
class EditCommunityScreen extends ConsumerStatefulWidget {
  const EditCommunityScreen({
    required this.community,
    super.key,
  });

  final CommunityEntity community;

  @override
  ConsumerState<EditCommunityScreen> createState() =>
      _EditCommunityScreenState();
}

class _EditCommunityScreenState extends ConsumerState<EditCommunityScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _localityController;
  late final TextEditingController _neighborhoodController;

  late CommunityCategory _selectedCategory;
  late String _visibility;
  bool _isSubmitting = false;
  String? _nameError;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.community.name);
    _descriptionController =
        TextEditingController(text: widget.community.description);
    _localityController =
        TextEditingController(text: widget.community.locality ?? '');
    _neighborhoodController =
        TextEditingController(text: widget.community.neighborhood ?? '');
    _selectedCategory = widget.community.category;
    _visibility = widget.community.visibility;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _localityController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    String? nameError;
    if (name.isEmpty) {
      nameError = 'Please enter a name';
    } else if (name.length < 3) {
      nameError = 'Name must be at least 3 characters';
    }

    String? descError;
    if (description.isEmpty) {
      descError = 'Please enter a description';
    } else if (description.length < 10) {
      descError = 'Description must be at least 10 characters';
    }

    if (nameError != null || descError != null) {
      setState(() {
        _nameError = nameError;
        _descriptionError = descError;
      });
      return;
    }

    setState(() {
      _nameError = null;
      _descriptionError = null;
      _isSubmitting = true;
    });

    try {
      final controller = ref.read(
        communityDetailControllerProvider(widget.community.id).notifier,
      );

      final success = await controller.updateCommunity(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        visibility: _visibility,
        locality: _localityController.text.trim().isEmpty
            ? null
            : _localityController.text.trim(),
        neighborhood: _neighborhoodController.text.trim().isEmpty
            ? null
            : _neighborhoodController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          context.pop();
          AppSnackbar.showSuccess(
            context,
            message: 'Community settings updated successfully.',
          );
        } else {
          AppSnackbar.showError(
            context,
            message: 'Failed to update community settings.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(
          context,
          message: 'An error occurred while saving.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Community'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButton(
            text: 'Save Changes',
            isLoading: _isSubmitting,
            onPressed: _save,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Community Name',
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),

            AppSpacing.gapVMd,

            AppTextField(
              controller: _descriptionController,
              label: 'Description',
              maxLines: 4,
              errorText: _descriptionError,
              onChanged: (_) {
                if (_descriptionError != null) {
                  setState(() => _descriptionError = null);
                }
              },
            ),

            AppSpacing.gapVLg,

            Text(
              'Category',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.pureWhite : AppColors.slate900,
              ),
            ),
            AppSpacing.gapVSm,

            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: CommunityCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return AppChip(
                  label: cat.label,
                  icon: cat.icon,
                  isSelected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),

            AppSpacing.gapVLg,

            Text(
              'Privacy & Access',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.pureWhite : AppColors.slate900,
              ),
            ),
            AppSpacing.gapVSm,

            // Public choice
            InkWell(
              onTap: () => setState(() => _visibility = 'public'),
              borderRadius: AppRadius.card,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: _visibility == 'public'
                      ? (isDark
                          ? AppColors.indigo950.withValues(alpha: 0.5)
                          : AppColors.indigo50)
                      : (isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface),
                  borderRadius: AppRadius.card,
                  border: Border.all(
                    color: _visibility == 'public'
                        ? (isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        : (isDark
                            ? AppColors.darkOutlineVariant
                            : AppColors.lightOutlineVariant),
                    width: _visibility == 'public' ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.visibility,
                      size: 24,
                      color: _visibility == 'public'
                          ? (isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary)
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                    ),
                    AppSpacing.gapHMd,
                    Expanded(
                      child: Text(
                        'Public Community',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AppSpacing.gapVSm,

            // Private choice
            InkWell(
              onTap: () => setState(() => _visibility = 'private'),
              borderRadius: AppRadius.card,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: _visibility == 'private'
                      ? (isDark
                          ? AppColors.indigo950.withValues(alpha: 0.5)
                          : AppColors.indigo50)
                      : (isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface),
                  borderRadius: AppRadius.card,
                  border: Border.all(
                    color: _visibility == 'private'
                        ? (isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        : (isDark
                            ? AppColors.darkOutlineVariant
                            : AppColors.lightOutlineVariant),
                    width: _visibility == 'private' ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.lock,
                      size: 24,
                      color: _visibility == 'private'
                          ? (isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary)
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                    ),
                    AppSpacing.gapHMd,
                    Expanded(
                      child: Text(
                        'Private Community',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AppSpacing.gapVLg,

            Text(
              'Locality Scoping',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.pureWhite : AppColors.slate900,
              ),
            ),
            AppSpacing.gapVSm,

            AppTextField(
              controller: _localityController,
              label: 'Locality',
            ),

            AppSpacing.gapVSm,

            AppTextField(
              controller: _neighborhoodController,
              label: 'Neighborhood / Sub-locality (optional)',
            ),
          ],
        ),
      ),
    );
  }
}

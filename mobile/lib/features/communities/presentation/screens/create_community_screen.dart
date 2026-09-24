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
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../application/communities_controller.dart';
import '../../data/repositories/communities_repository.dart';
import '../../domain/entities/community_category.dart';

/// Screen allowing authenticated users to create a new local community.
class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() =>
      _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _localityController = TextEditingController();
  final _neighborhoodController = TextEditingController();

  CommunityCategory _selectedCategory = CommunityCategory.society;
  String _visibility = 'public';
  bool _isSubmitting = false;
  String? _nameError;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authControllerProvider);
      if (authState is AuthAuthenticated) {
        if (authState.user.locality != null) {
          _localityController.text = authState.user.locality!;
        }
        if (authState.user.neighborhood != null) {
          _neighborhoodController.text = authState.user.neighborhood!;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _localityController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    String? nameError;
    if (name.isEmpty) {
      nameError = 'Please enter a community name';
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
      final repository = ref.read(communitiesRepositoryProvider);
      final newCommunity = await repository.createCommunity(
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

      // Prepend to controller
      ref
          .read(communitiesControllerProvider.notifier)
          .addCommunity(newCommunity);

      if (mounted) {
        context.pop();
        context.push('/communities/${newCommunity.id}');
        AppSnackbar.showSuccess(
          context,
          message: 'Community "${newCommunity.name}" created successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(
          context,
          message:
              'Failed to create community. A community with this name may already exist.',
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
        title: const Text('Create Community'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButton(
            text: 'Create Community',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Community Name
            AppTextField(
              controller: _nameController,
              label: 'Community Name',
              hint: 'e.g. Palm Meadows Residents, Indiranagar Runners',
              prefixIcon: AppIcons.communities,
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),

            AppSpacing.gapVMd,

            // Description
            AppTextField(
              controller: _descriptionController,
              label: 'Description',
              hint:
                  'What is this community about? What should neighbors know before joining?',
              maxLines: 4,
              errorText: _descriptionError,
              onChanged: (_) {
                if (_descriptionError != null) {
                  setState(() => _descriptionError = null);
                }
              },
            ),

            AppSpacing.gapVLg,

            // Category Selector
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

            // Visibility Choice (Public vs Private)
            Text(
              'Privacy & Access',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.pureWhite : AppColors.slate900,
              ),
            ),
            AppSpacing.gapVSm,

            // Public Card
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Public Community',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          AppSpacing.gapHXxs,
                          Text(
                            'Anyone in the neighborhood can discover this group and see discussions.',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AppSpacing.gapVSm,

            // Private Card
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Private Community',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          AppSpacing.gapHXxs,
                          Text(
                            'Discussions are visible only to members. Neighbors must join to participate.',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AppSpacing.gapVLg,

            // Location scoping
            Text(
              'Community Locality',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.pureWhite : AppColors.slate900,
              ),
            ),
            AppSpacing.gapVSm,

            AppTextField(
              controller: _localityController,
              label: 'Locality',
              hint: 'e.g. Indiranagar, Whitefield',
              prefixIcon: AppIcons.location,
            ),

            AppSpacing.gapVSm,

            AppTextField(
              controller: _neighborhoodController,
              label: 'Neighborhood / Sub-locality (optional)',
              hint: 'e.g. Defence Colony, Stage 2',
            ),
          ],
        ),
      ),
    );
  }
}

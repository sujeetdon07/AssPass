import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/onboarding_controller.dart';

/// Step 4 of onboarding: Basic Profile setup (Display Name & optional avatar).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final currentName = ref.read(onboardingControllerProvider).displayName;
    if (currentName.isNotEmpty) {
      _nameController.text = currentName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    final text = _nameController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _nameError = 'Please enter your name.';
      });
      return;
    }
    if (text.length < 2) {
      setState(() {
        _nameError = 'Name must be at least 2 characters long.';
      });
      return;
    }
    if (text.length > 50) {
      setState(() {
        _nameError = 'Name cannot exceed 50 characters.';
      });
      return;
    }

    setState(() {
      _nameError = null;
    });

    ref.read(onboardingControllerProvider.notifier).setDisplayName(text);

    context.push(AppRoutes.localitySetup);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSpacing.gapVLg,

                // Progress Indicator (Step 1 of 2 in profile setup)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    AppSpacing.gapHSm,
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),

                AppSpacing.gapVLg,

                // Title
                Text(
                  'Tell us a little about you',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),

                AppSpacing.gapVSm,

                // Subtitle
                Text(
                  'Your neighbors will know you by this name in your local community.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.4,
                  ),
                ),

                AppSpacing.gapVLg,

                // Avatar Foundation Preview
                Center(
                  child: Stack(
                    children: [
                      const AppAvatar(
                        size: AppAvatarSize.s72,
                        semanticLabel: 'Profile photo placeholder',
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            AppIcons.edit,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                AppSpacing.gapVXs,

                Center(
                  child: Text(
                    'Photo upload will be available in future updates',
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                      fontSize: 11,
                    ),
                  ),
                ),

                AppSpacing.gapVLg,

                // Name Field
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'e.g. Sujeet Sharma',
                  prefixIcon: AppIcons.profile,
                  errorText: _nameError,
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() {
                        _nameError = null;
                      });
                    }
                  },
                  onSubmitted: (_) => _handleContinue(),
                ),

                AppSpacing.gapVLg,

                // Continue Button
                AppButton(
                  text: 'Continue',
                  variant: AppButtonVariant.primary,
                  onPressed: _handleContinue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

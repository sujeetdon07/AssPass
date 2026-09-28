import 'dart:async';
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
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../shell/presentation/screens/edit_profile_screen.dart';
import '../../application/onboarding_controller.dart';

/// Step 4 of onboarding: Basic Profile setup (Display Name & optional username).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  Timer? _debounceTimer;
  UsernameAvailabilityState _usernameState = UsernameAvailabilityState.idle;
  String? _usernameMessage;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final onboardingState = ref.read(onboardingControllerProvider);
    final currentName = onboardingState.displayName;
    if (currentName.isNotEmpty) {
      _nameController.text = currentName;
    }
    final currentUsername = onboardingState.username;
    if (currentUsername != null && currentUsername.isNotEmpty) {
      _usernameController.text = currentUsername;
      _usernameState = UsernameAvailabilityState.available;
      _usernameMessage = 'Username selected';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    final clean = value.trim().startsWith('@')
        ? value.trim().substring(1).trim()
        : value.trim();

    if (clean.isEmpty) {
      setState(() {
        _usernameState = UsernameAvailabilityState.idle;
        _usernameMessage = null;
      });
      return;
    }

    final regex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
    if (!regex.hasMatch(clean)) {
      setState(() {
        _usernameState = UsernameAvailabilityState.invalid;
        if (clean.length < 3) {
          _usernameMessage = 'Must be at least 3 characters';
        } else if (clean.length > 30) {
          _usernameMessage = 'Must be 30 characters or fewer';
        } else {
          _usernameMessage = 'Only letters, numbers, and _ allowed';
        }
      });
      return;
    }

    setState(() {
      _usernameState = UsernameAvailabilityState.checking;
      _usernameMessage = 'Checking availability...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await ref
            .read(authRepositoryProvider)
            .checkUsernameAvailability(clean);

        if (!mounted) return;
        final currentText = _usernameController.text.trim();
        final currentClean = currentText.startsWith('@')
            ? currentText.substring(1).trim()
            : currentText;

        if (currentClean.toLowerCase() != clean.toLowerCase()) return;

        setState(() {
          if (result.available) {
            _usernameState = UsernameAvailabilityState.available;
            _usernameMessage = 'Username is available';
          } else {
            _usernameState = UsernameAvailabilityState.unavailable;
            _usernameMessage = result.message ?? 'Username already taken';
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _usernameState = UsernameAvailabilityState.error;
          _usernameMessage = 'Error checking username';
        });
      }
    });
  }

  Widget? _buildUsernameStatusIndicator(bool isDark) {
    switch (_usernameState) {
      case UsernameAvailabilityState.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case UsernameAvailabilityState.available:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(
            Icons.check_circle_rounded,
            color: AppColors.emerald500,
            size: 20,
          ),
        );
      case UsernameAvailabilityState.unavailable:
      case UsernameAvailabilityState.invalid:
      case UsernameAvailabilityState.error:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(
            Icons.cancel_rounded,
            color: AppColors.rose500,
            size: 20,
          ),
        );
      case UsernameAvailabilityState.idle:
        return null;
    }
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

    final rawUsername = _usernameController.text.trim();
    final cleanUsername = rawUsername.startsWith('@')
        ? rawUsername.substring(1).trim()
        : rawUsername;

    if (cleanUsername.isNotEmpty) {
      if (_usernameState == UsernameAvailabilityState.invalid ||
          _usernameState == UsernameAvailabilityState.unavailable ||
          _usernameState == UsernameAvailabilityState.error) {
        return;
      }
      ref
          .read(onboardingControllerProvider.notifier)
          .setUsername(cleanUsername.toLowerCase());
    } else {
      ref.read(onboardingControllerProvider.notifier).setUsername(null);
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

                AppSpacing.gapVMd,

                // Optional Username Field
                AppTextField(
                  controller: _usernameController,
                  label: 'Username (Optional)',
                  hint: 'your_username',
                  prefixWidget: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Text(
                      '@',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                    ),
                  ),
                  suffixWidget: _buildUsernameStatusIndicator(isDark),
                  helperText: _usernameState ==
                          UsernameAvailabilityState.available
                      ? '✓ $_usernameMessage'
                      : (_usernameState == UsernameAvailabilityState.checking
                          ? 'Checking availability...'
                          : '3–30 characters: letters, numbers, or _. (Can also be set later in Profile)'),
                  errorText: (_usernameState ==
                              UsernameAvailabilityState.invalid ||
                          _usernameState ==
                              UsernameAvailabilityState.unavailable ||
                          _usernameState == UsernameAvailabilityState.error)
                      ? _usernameMessage
                      : null,
                  onChanged: _onUsernameChanged,
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

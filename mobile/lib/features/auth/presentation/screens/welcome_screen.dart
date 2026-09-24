import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';

/// Step 1 of onboarding: Welcome to Aaspaas landing screen.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),

                // Brand Emblem Card
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                AppColors.darkPrimary,
                                AppColors.darkSecondary,
                              ]
                            : [
                                AppColors.lightPrimary,
                                AppColors.lightSecondary,
                              ],
                      ),
                      borderRadius: AppRadius.card,
                      boxShadow: [
                        BoxShadow(
                          color: (isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary)
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      AppIcons.home,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),

                AppSpacing.gapVLg,

                // App Title
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),

                AppSpacing.gapVXs,

                // Tagline
                Text(
                  AppConstants.appTagline,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                ),

                AppSpacing.gapVMd,

                // Hyperlocal Description
                Text(
                  'Connect with verified neighbors, stay informed about local updates, and discover local communities in your neighborhood.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 2),

                // Key Pillars / Benefits Preview
                _buildBenefitItem(
                  context,
                  icon: AppIcons.verified,
                  title: 'Verified Local Community',
                  subtitle: 'Genuine neighbors and local societies around you.',
                  isDark: isDark,
                ),
                AppSpacing.gapVMd,
                _buildBenefitItem(
                  context,
                  icon: AppIcons.privacy,
                  title: 'Privacy First',
                  subtitle: 'Your exact home address is never shared publicly.',
                  isDark: isDark,
                ),

                const Spacer(flex: 2),

                // Get Started Button
                AppButton(
                  text: 'Get Started',
                  variant: AppButtonVariant.primary,
                  onPressed: () => context.push(AppRoutes.phone),
                ),

                AppSpacing.gapVMd,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant,
            borderRadius: AppRadius.input,
          ),
          child: Icon(
            icon,
            size: 22,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          ),
        ),
        AppSpacing.gapHMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                subtitle,
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
    );
  }
}

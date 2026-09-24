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
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/chips/app_badge.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/onboarding_controller.dart';

/// Step 6 of onboarding: All Set completion screen.
class CompletionScreen extends ConsumerWidget {
  const CompletionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formState = ref.watch(onboardingControllerProvider);
    final user = formState.completedUser;

    final String displayName;
    if (user != null &&
        user.displayName != null &&
        user.displayName!.isNotEmpty) {
      displayName = user.displayName!;
    } else if (formState.displayName.isNotEmpty) {
      displayName = formState.displayName;
    } else {
      displayName = 'Neighbor';
    }

    final String locality;
    if (user != null && user.localitySummary.isNotEmpty) {
      locality = user.localitySummary;
    } else if (formState.selectedLocality != null) {
      locality = formState.selectedLocality!.displayName;
    } else {
      locality = 'Your Locality';
    }

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),

                // Success Animated Emblem
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: (isDark
                              ? AppColors.darkSuccess
                              : AppColors.lightSuccess)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSuccess
                            : AppColors.lightSuccess,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      AppIcons.check,
                      size: 48,
                      color: isDark
                          ? AppColors.darkSuccess
                          : AppColors.lightSuccess,
                    ),
                  ),
                ),

                AppSpacing.gapVLg,

                // Headline
                Text(
                  "You're all set!",
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),

                AppSpacing.gapVSm,

                Text(
                  'Welcome to your local world on Aaspaas. You are now ready to connect with your neighborhood.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.4,
                  ),
                ),

                const Spacer(flex: 1),

                // User Identity Card
                AppCard(
                  child: Column(
                    children: [
                      const AppAvatar(
                        size: AppAvatarSize.s72,
                        semanticLabel: 'User profile avatar',
                      ),
                      AppSpacing.gapVMd,
                      Text(
                        displayName,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      AppSpacing.gapVXs,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            AppIcons.location,
                            size: 16,
                            color: isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary,
                          ),
                          AppSpacing.gapHXs,
                          Text(
                            locality,
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapVMd,
                      const AppBadge(
                        label: 'Verified Member',
                        variant: AppBadgeVariant.success,
                        icon: AppIcons.verified,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Continue to Aaspaas Action
                AppButton(
                  text: 'Continue to Aaspaas',
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    context.go(AppRoutes.home);
                  },
                ),

                AppSpacing.gapVMd,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

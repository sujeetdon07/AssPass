import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/onboarding_controller.dart';
import '../../data/repositories/onboarding_repository.dart';

/// Step 5 of onboarding: Locality and neighborhood selection with strict privacy controls.
class LocalitySetupScreen extends ConsumerStatefulWidget {
  const LocalitySetupScreen({super.key});

  @override
  ConsumerState<LocalitySetupScreen> createState() =>
      _LocalitySetupScreenState();
}

class _LocalitySetupScreenState extends ConsumerState<LocalitySetupScreen> {
  final _searchController = TextEditingController();
  final _neighborhoodController = TextEditingController();

  List<LocalitySuggestion> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadPopularLocalities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularLocalities() async {
    final repo = ref.read(onboardingRepositoryProvider);
    final popular = await repo.getPopularLocalities();
    if (mounted) {
      setState(() {
        _suggestions = popular;
      });
    }
  }

  Future<void> _handleSearch(String query) async {
    final repo = ref.read(onboardingRepositoryProvider);
    setState(() {
      _isSearching = true;
    });

    final results = await repo.searchLocalities(query);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    final formState = ref.read(onboardingControllerProvider);
    if (formState.selectedLocality == null) {
      AppSnackbar.showError(
        context,
        message: 'Please select your locality from the list.',
      );
      return;
    }

    if (_neighborhoodController.text.trim().isNotEmpty) {
      ref
          .read(onboardingControllerProvider.notifier)
          .setNeighborhood(_neighborhoodController.text.trim());
    }

    try {
      await ref.read(onboardingControllerProvider.notifier).submitOnboarding();
      if (mounted) {
        context.push(AppRoutes.onboardingComplete);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formState = ref.watch(onboardingControllerProvider);
    final selectedLocality = formState.selectedLocality;

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.arrowBack,
          semanticLabel: 'Back to profile setup',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress Bar (Step 2 of 2)
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
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),

                AppSpacing.gapVMd,

                // Title
                Text(
                  'Where do you live?',
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
                  'Locality helps Aaspaas connect you with verified local communities and relevant neighbor updates.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.4,
                  ),
                ),

                AppSpacing.gapVMd,

                // Privacy Banner (Critical Requirement)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    borderRadius: AppRadius.card,
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutline
                          : AppColors.lightOutline,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        AppIcons.privacy,
                        size: 20,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                      AppSpacing.gapHMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Privacy Guarantee',
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            AppSpacing.gapVXs,
                            Text(
                              'Aaspaas never shares your exact home address or GPS coordinates. Only your general locality is used to group local discussions.',
                              style: AppTypography.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                AppSpacing.gapVLg,

                // Locality Search Field
                AppSearchBar(
                  controller: _searchController,
                  hint: 'Search city or locality (e.g. Indiranagar)',
                  onChanged: _handleSearch,
                ),

                AppSpacing.gapVMd,

                // Selected Locality Card
                if (selectedLocality != null) ...[
                  AppCard(
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.location,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                        AppSpacing.gapHMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedLocality.locality,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                '${selectedLocality.city}, ${selectedLocality.state}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          AppIcons.check,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVMd,

                  // Optional Neighborhood / Society Field
                  AppTextField(
                    controller: _neighborhoodController,
                    label: 'Society or Neighborhood (Optional)',
                    hint: 'e.g. Defence Colony, Pocket B',
                    prefixIcon: AppIcons.home,
                  ),
                  AppSpacing.gapVMd,
                ],

                // Locality Suggestions List
                Text(
                  selectedLocality == null
                      ? 'Popular Localities'
                      : 'Change Locality',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                AppSpacing.gapVSm,

                if (_isSearching)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      final isSelected = item.id == selectedLocality?.id;

                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        leading: Icon(
                          AppIcons.location,
                          size: 20,
                          color: isSelected
                              ? (isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary)
                              : (isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary),
                        ),
                        title: Text(
                          item.locality,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${item.city}, ${item.state}',
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        onTap: () {
                          ref
                              .read(onboardingControllerProvider.notifier)
                              .setLocality(item);
                        },
                      );
                    },
                  ),

                AppSpacing.gapVLg,

                // Continue Action
                AppButton(
                  text: 'Complete Setup',
                  variant: AppButtonVariant.primary,
                  isLoading: formState.isLoading,
                  onPressed: formState.isLoading || selectedLocality == null
                      ? null
                      : _handleSubmit,
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

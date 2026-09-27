import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
import '../../../nearby/domain/services/location_service.dart';
import '../../application/onboarding_controller.dart';
import '../../data/repositories/onboarding_repository.dart';

/// Step 5 of onboarding: Locality and neighborhood selection with GPS auto-detection,
/// live universal search, and keyboard-friendly layout.
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
  bool _isDetectingLocation = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadPopularLocalities();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _loadPopularLocalities();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _handleSearch(trimmed);
    });
  }

  Future<void> _handleSearch(String query) async {
    final repo = ref.read(onboardingRepositoryProvider);
    if (!mounted) return;
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

  Future<void> _handleUseCurrentLocation() async {
    if (_isDetectingLocation) return;
    setState(() {
      _isDetectingLocation = true;
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final serviceEnabled = await locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppSnackbar.showWarning(
            context,
            message:
                'Please enable GPS / Location services to auto-detect your area.',
          );
          await locationService.openLocationSettings();
        }
        return;
      }

      var permission = await locationService.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await locationService.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppSnackbar.showWarning(
              context,
              message:
                  'Location permission is required to detect your locality.',
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppSnackbar.showWarning(
            context,
            message:
                'Location permission is permanently denied. Please enable it in Settings.',
          );
          await locationService.openAppSettings();
        }
        return;
      }

      final position = await locationService.getCurrentPosition();
      if (position == null) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            message:
                'Could not obtain GPS location. Please select your locality manually.',
          );
        }
        return;
      }

      final repo = ref.read(onboardingRepositoryProvider);
      final locality = await repo.fetchCurrentLocationLocality(
        lat: position.latitude,
        lng: position.longitude,
      );

      if (locality != null && mounted) {
        ref.read(onboardingControllerProvider.notifier).setLocality(locality);
        _searchController.clear();
        FocusScope.of(context).unfocus();
        AppSnackbar.showSuccess(
          context,
          message:
              'Detected locality: ${locality.locality}, ${locality.city}',
        );
      } else if (mounted) {
        AppSnackbar.showWarning(
          context,
          message:
              'Could not automatically identify your locality. Please search your colony or sector.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message:
              'Location detection error: ${e.toString().replaceAll("Exception: ", "")}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  void _selectCustomLocality(String customName) {
    final trimmed = customName.trim();
    if (trimmed.isEmpty) return;

    final item = LocalitySuggestion(
      id: 'custom-${trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}',
      countryCode: 'IN',
      state: '',
      district: '',
      city: trimmed,
      locality: trimmed,
    );

    FocusScope.of(context).unfocus();
    ref.read(onboardingControllerProvider.notifier).setLocality(item);
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
    final searchQuery = _searchController.text.trim();

    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.arrowBack,
          semanticLabel: 'Back to profile setup',
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.darkOutlineVariant
                    : AppColors.lightOutlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: AppButton(
            text: selectedLocality == null
                ? 'Select your locality'
                : 'Complete Setup',
            variant: AppButtonVariant.primary,
            isLoading: formState.isLoading,
            onPressed: formState.isLoading || selectedLocality == null
                ? null
                : _handleSubmit,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      // Progress Bar (Step 2 of 2)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          AppSpacing.gapHSm,
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: primaryColor,
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

                      // Privacy Banner
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
                              color: primaryColor,
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
                        hint:
                            'Search city, sector, colony (e.g. Noida, Sasaram)',
                        onChanged: _onSearchChanged,
                        onClear: () {
                          _searchController.clear();
                          _loadPopularLocalities();
                        },
                      ),

                      AppSpacing.gapVMd,

                      // "Use Current Location" Quick Action Tile
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: AppRadius.card,
                          onTap: _isDetectingLocation
                              ? null
                              : _handleUseCurrentLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
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
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.my_location_rounded,
                                    size: 20,
                                    color: primaryColor,
                                  ),
                                ),
                                AppSpacing.gapHMd,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Use Current Location',
                                        style:
                                            AppTypography.titleSmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Auto-detect your area via GPS',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isDetectingLocation)
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primaryColor,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.lightTextTertiary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      AppSpacing.gapVMd,

                      // Selected Locality Card
                      if (selectedLocality != null) ...[
                        AppCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  AppIcons.check,
                                  size: 18,
                                  color: primaryColor,
                                ),
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
                                      '${selectedLocality.city}, ${selectedLocality.state}${selectedLocality.postalCode != null ? ' - ${selectedLocality.postalCode}' : ''}',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _loadPopularLocalities();
                                },
                                child: Text(
                                  'Change',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapVMd,

                        // Optional Society / Neighborhood / Apartment field
                        AppTextField(
                          controller: _neighborhoodController,
                          label: 'Society, Colony or Apartment (Optional)',
                          hint: 'e.g. Antriksh Golf View, Pocket B',
                          prefixIcon: AppIcons.home,
                        ),
                        AppSpacing.gapVMd,
                      ],

                      // Locality Suggestions Header
                      Text(
                        searchQuery.isNotEmpty
                            ? 'Search Results'
                            : (selectedLocality == null
                                ? 'Popular Localities'
                                : 'Other Localities'),
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      AppSpacing.gapVSm,
                    ],
                  ),
                ),
              ),

              // Suggestions & Results List
              if (_isSearching)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else ...[
                // Custom locality option if search query doesn't match exactly
                if (searchQuery.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: AppRadius.card,
                          onTap: () => _selectCustomLocality(searchQuery),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              borderRadius: AppRadius.card,
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_location_alt_rounded,
                                  size: 20,
                                  color: primaryColor,
                                ),
                                AppSpacing.gapHMd,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Use "$searchQuery"',
                                        style:
                                            AppTypography.titleSmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                      Text(
                                        'Set as custom locality / society',
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
                                  size: 16,
                                  color: primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Suggestions List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _suggestions[index];
                        final isSelected = item.id == selectedLocality?.id;

                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? AppColors.darkOutlineVariant
                                    : AppColors.lightOutlineVariant,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            leading: Icon(
                              AppIcons.location,
                              size: 20,
                              color: isSelected
                                  ? primaryColor
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
                              '${item.city}, ${item.state}${item.postalCode != null ? ' (${item.postalCode})' : ''}',
                              style: AppTypography.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    AppIcons.checkCircle,
                                    size: 18,
                                    color: primaryColor,
                                  )
                                : null,
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              ref
                                  .read(onboardingControllerProvider.notifier)
                                  .setLocality(item);
                            },
                          ),
                        );
                      },
                      childCount: _suggestions.length,
                    ),
                  ),
                ),

                // Bottom padding sliver so content doesn't get obscured
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../onboarding/data/repositories/onboarding_repository.dart';

/// Mapping of known localities to public discovery centroids.
const Map<String, ({double lat, double lng})> kLocalityCoordinates = {
  'indiranagar': (lat: 12.9784, lng: 77.6408),
  'koramangala': (lat: 12.9352, lng: 77.6245),
  'hsr layout': (lat: 12.9121, lng: 77.6446),
  'hsr': (lat: 12.9121, lng: 77.6446),
  'whitefield': (lat: 12.9698, lng: 77.7500),
  'connaught place': (lat: 28.6315, lng: 77.2167),
  'hauz khas': (lat: 28.5494, lng: 77.2001),
  'saket': (lat: 28.5244, lng: 77.2177),
  'bandra west': (lat: 19.0596, lng: 72.8295),
  'bandra': (lat: 19.0596, lng: 72.8295),
  'andheri west': (lat: 19.1363, lng: 72.8277),
  'andheri': (lat: 19.1363, lng: 72.8277),
  'colaba': (lat: 18.9067, lng: 72.8147),
  'koregaon park': (lat: 18.5362, lng: 73.8940),
  'banjara hills': (lat: 17.4156, lng: 78.4350),
};

({double lat, double lng}) getCoordinatesForLocality(
  String locality,
  String city,
) {
  final lKey = locality.toLowerCase().trim();
  for (final entry in kLocalityCoordinates.entries) {
    if (lKey.contains(entry.key)) {
      return entry.value;
    }
  }

  final cKey = city.toLowerCase().trim();
  if (cKey.contains('delhi')) return (lat: 28.6139, lng: 77.2090);
  if (cKey.contains('mumbai')) return (lat: 19.0760, lng: 72.8777);
  if (cKey.contains('pune')) return (lat: 18.5204, lng: 73.8567);
  if (cKey.contains('hyderabad')) return (lat: 17.3850, lng: 78.4867);

  // Default Bengaluru
  return (lat: 12.9716, lng: 77.5946);
}

/// Modal dialog allowing users to pick a manual fallback locality for Nearby discovery.
class LocalityPickerDialog extends ConsumerStatefulWidget {
  const LocalityPickerDialog({super.key});

  static Future<({String locality, String city, double lat, double lng})?> show(
    BuildContext context,
  ) {
    return showModalBottomSheet<
        ({String locality, String city, double lat, double lng})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocalityPickerDialog(),
    );
  }

  @override
  ConsumerState<LocalityPickerDialog> createState() =>
      _LocalityPickerDialogState();
}

class _LocalityPickerDialogState extends ConsumerState<LocalityPickerDialog> {
  final _searchController = TextEditingController();
  List<LocalitySuggestion> _results = [];
  bool _isLoading = false;

  final List<LocalitySuggestion> _defaultLocalities = const [
    LocalitySuggestion(
      id: 'loc-blr-01',
      countryCode: 'IN',
      state: 'Karnataka',
      district: 'Bengaluru Urban',
      city: 'Bengaluru',
      locality: 'Indiranagar',
    ),
    LocalitySuggestion(
      id: 'loc-blr-02',
      countryCode: 'IN',
      state: 'Karnataka',
      district: 'Bengaluru Urban',
      city: 'Bengaluru',
      locality: 'Koramangala',
    ),
    LocalitySuggestion(
      id: 'loc-blr-03',
      countryCode: 'IN',
      state: 'Karnataka',
      district: 'Bengaluru Urban',
      city: 'Bengaluru',
      locality: 'HSR Layout',
    ),
    LocalitySuggestion(
      id: 'loc-blr-04',
      countryCode: 'IN',
      state: 'Karnataka',
      district: 'Bengaluru Urban',
      city: 'Bengaluru',
      locality: 'Whitefield',
    ),
    LocalitySuggestion(
      id: 'loc-del-01',
      countryCode: 'IN',
      state: 'Delhi',
      district: 'New Delhi',
      city: 'New Delhi',
      locality: 'Connaught Place',
    ),
    LocalitySuggestion(
      id: 'loc-mum-01',
      countryCode: 'IN',
      state: 'Maharashtra',
      district: 'Mumbai Suburban',
      city: 'Mumbai',
      locality: 'Bandra West',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _results = _defaultLocalities;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = _defaultLocalities);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final list = await repo.searchLocalities(query);
      if (mounted) {
        setState(() {
          _results = list.isNotEmpty
              ? list
              : _defaultLocalities
                  .where(
                    (loc) =>
                        loc.locality
                            .toLowerCase()
                            .contains(query.toLowerCase()) ||
                        loc.city.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = _defaultLocalities
              .where(
                (loc) =>
                    loc.locality.toLowerCase().contains(query.toLowerCase()) ||
                    loc.city.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                borderRadius: AppRadius.chip,
              ),
            ),
          ),
          AppSpacing.gapVMd,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Choose Locality',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            'Explore nearby posts without sharing your device location',
            style: AppTypography.bodySmall.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          AppSpacing.gapVMd,
          AppTextField(
            controller: _searchController,
            hint: 'Search locality or city...',
            prefixIcon: Icons.search,
            onChanged: _search,
          ),
          AppSpacing.gapVMd,
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.darkOutline
                          : AppColors.lightOutline,
                    ),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.location,
                            size: 16,
                            color: primaryColor,
                          ),
                        ),
                        title: Text(
                          item.locality,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${item.city}, ${item.state}',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        onTap: () {
                          final coords = getCoordinatesForLocality(
                            item.locality,
                            item.city,
                          );
                          Navigator.of(context).pop(
                            (
                              locality: item.locality,
                              city: item.city,
                              lat: coords.lat,
                              lng: coords.lng,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

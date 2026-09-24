import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/chips/app_chip.dart';
import '../../domain/entities/business_category.dart';
import '../../domain/entities/business_filter.dart';

class BusinessFilterSheet extends StatefulWidget {
  const BusinessFilterSheet({
    required this.initialFilter,
    required this.onApply,
    super.key,
  });

  final BusinessFilter initialFilter;
  final ValueChanged<BusinessFilter> onApply;

  static Future<BusinessFilter?> show(
    BuildContext context, {
    required BusinessFilter initialFilter,
  }) {
    return showModalBottomSheet<BusinessFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BusinessFilterSheet(
        initialFilter: initialFilter,
        onApply: (filter) => Navigator.of(context).pop(filter),
      ),
    );
  }

  @override
  State<BusinessFilterSheet> createState() => _BusinessFilterSheetState();
}

class _BusinessFilterSheetState extends State<BusinessFilterSheet> {
  late BusinessCategory? _selectedCategory;
  late TextEditingController _localityController;
  late double? _selectedRadius;
  late bool _openNow;
  late BusinessSortOption _sortBy;

  final List<double> _radiusOptions = [1, 3, 5, 10, 20];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialFilter.category;
    _localityController =
        TextEditingController(text: widget.initialFilter.locality ?? '');
    _selectedRadius = widget.initialFilter.radiusKm;
    _openNow = widget.initialFilter.openNow;
    _sortBy = widget.initialFilter.sortBy;
  }

  @override
  void dispose() {
    _localityController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _selectedCategory = null;
      _localityController.clear();
      _selectedRadius = null;
      _openNow = false;
      _sortBy = BusinessSortOption.newest;
    });
  }

  void _apply() {
    final localityText = _localityController.text.trim();
    final filter = BusinessFilter(
      searchQuery: widget.initialFilter.searchQuery,
      category: _selectedCategory,
      locality: localityText.isNotEmpty ? localityText : null,
      radiusKm: _selectedRadius,
      openNow: _openNow,
      sortBy: _sortBy,
    );
    widget.onApply(filter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate700 : AppColors.slate300,
                  borderRadius: AppRadius.borderPill,
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Businesses',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: Text(
                      'Reset',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Filter controls scroll view
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Category Section ───────────────────────────────────────
                    Text(
                      'Category',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    AppSpacing.gapVSm,
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: BusinessCategory.values.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return AppChip(
                          label: cat.label,
                          icon: cat.icon,
                          isSelected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? cat : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    AppSpacing.gapVMd,

                    // ── Open Now Toggle ────────────────────────────────────────
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Open Now',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Show only businesses currently open',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      value: _openNow,
                      activeTrackColor: AppColors.indigo600,
                      onChanged: (val) {
                        setState(() {
                          _openNow = val;
                        });
                      },
                    ),
                    AppSpacing.gapVMd,

                    // ── Locality Input ─────────────────────────────────────────
                    Text(
                      'Locality',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    AppSpacing.gapVXs,
                    TextField(
                      controller: _localityController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Indiranagar, Koramangala',
                        prefixIcon: const Icon(AppIcons.location, size: 20),
                        suffixIcon: _localityController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(AppIcons.close, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _localityController.clear();
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurfaceContainer
                            : AppColors.lightSurfaceContainer,
                        border: const OutlineInputBorder(
                          borderRadius: AppRadius.borderMd,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    AppSpacing.gapVMd,

                    // ── Discovery Radius ───────────────────────────────────────
                    Text(
                      'Discovery Radius',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    AppSpacing.gapVSm,
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: _radiusOptions.map((r) {
                        final isSelected = _selectedRadius == r;
                        return AppChip(
                          label: '${r.toInt()} km',
                          isSelected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedRadius = selected ? r : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    AppSpacing.gapVMd,

                    // ── Sort By ────────────────────────────────────────────────
                    Text(
                      'Sort By',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    AppSpacing.gapVSm,
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: BusinessSortOption.values.map((sort) {
                        final isSelected = _sortBy == sort;
                        return AppChip(
                          label: sort.label,
                          icon: sort == BusinessSortOption.nearest
                              ? AppIcons.location
                              : AppIcons.sort,
                          isSelected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _sortBy = sort;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    AppSpacing.gapVLg,
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                mediaQuery.padding.bottom + AppSpacing.md,
              ),
              child: AppButton(
                text: 'Apply Filters',
                isFullWidth: true,
                onPressed: _apply,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

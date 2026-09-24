import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../domain/entities/marketplace_category.dart';
import '../../domain/entities/marketplace_condition.dart';
import '../../domain/entities/marketplace_filter.dart';

/// Modal bottom sheet for customizing marketplace discovery filters.
class MarketplaceFilterSheet extends StatefulWidget {
  const MarketplaceFilterSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  final MarketplaceFilter initialFilter;
  final ValueChanged<MarketplaceFilter> onApply;

  static Future<void> show({
    required BuildContext context,
    required MarketplaceFilter currentFilter,
    required ValueChanged<MarketplaceFilter> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MarketplaceFilterSheet(
        initialFilter: currentFilter,
        onApply: onApply,
      ),
    );
  }

  @override
  State<MarketplaceFilterSheet> createState() => _MarketplaceFilterSheetState();
}

class _MarketplaceFilterSheetState extends State<MarketplaceFilterSheet> {
  late MarketplaceCategory? _selectedCategory;
  late MarketplaceCondition? _selectedCondition;
  late String _selectedSortBy;
  late int _selectedRadiusKm;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  final List<int> _radiusOptions = [1, 3, 5, 10, 20];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialFilter.category;
    _selectedCondition = widget.initialFilter.condition;
    _selectedSortBy = widget.initialFilter.sortBy;
    _selectedRadiusKm = widget.initialFilter.radiusKm;
    _minPriceController = TextEditingController(
      text: widget.initialFilter.minPrice != null
          ? widget.initialFilter.minPrice!.toInt().toString()
          : '',
    );
    _maxPriceController = TextEditingController(
      text: widget.initialFilter.maxPrice != null
          ? widget.initialFilter.maxPrice!.toInt().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _selectedCategory = null;
      _selectedCondition = null;
      _selectedSortBy = 'newest';
      _selectedRadiusKm = 5;
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  void _apply() {
    final minPrice = double.tryParse(_minPriceController.text.trim());
    final maxPrice = double.tryParse(_maxPriceController.text.trim());

    final filter = widget.initialFilter.copyWith(
      category: _selectedCategory,
      clearCategory: _selectedCategory == null,
      condition: _selectedCondition,
      clearCondition: _selectedCondition == null,
      minPrice: minPrice,
      clearMinPrice: minPrice == null,
      maxPrice: maxPrice,
      clearMaxPrice: maxPrice == null,
      radiusKm: _selectedRadiusKm,
      sortBy: _selectedSortBy,
    );

    widget.onApply(filter);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.bottomSheet,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag Handle ───────────────────────────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : AppColors.slate300,
                    borderRadius: AppRadius.borderPill,
                  ),
                ),
              ),

              // ── Header ────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters & Sorting',
                    style: AppTypography.titleLarge.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: Text(
                      'Reset All',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.indigo500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Sort By ───────────────────────────────────────────────────
              Text(
                'Sort Order',
                style: AppTypography.titleSmall.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _buildSortChip('newest', 'Newest First'),
                  _buildSortChip('price_asc', 'Price: Low to High'),
                  _buildSortChip('price_desc', 'Price: High to Low'),
                  _buildSortChip('nearest', 'Nearest to Me'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Discovery Radius ──────────────────────────────────────────
              Text(
                'Search Radius: $_selectedRadiusKm km',
                style: AppTypography.titleSmall.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: _radiusOptions.map((r) {
                  final isSelected = _selectedRadiusKm == r;
                  return ChoiceChip(
                    label: Text('$r km'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedRadiusKm = r);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Category ──────────────────────────────────────────────────
              Text(
                'Category',
                style: AppTypography.titleSmall.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('All Categories'),
                    selected: _selectedCategory == null,
                    onSelected: (_) => setState(() => _selectedCategory = null),
                  ),
                  ...MarketplaceCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      avatar: Icon(cat.icon, size: 16),
                      label: Text(cat.label),
                      selected: isSelected,
                      onSelected: (_) => setState(
                        () => _selectedCategory = isSelected ? null : cat,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Condition ─────────────────────────────────────────────────
              Text(
                'Item Condition',
                style: AppTypography.titleSmall.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('Any Condition'),
                    selected: _selectedCondition == null,
                    onSelected: (_) =>
                        setState(() => _selectedCondition = null),
                  ),
                  ...MarketplaceCondition.values.map((cond) {
                    final isSelected = _selectedCondition == cond;
                    return ChoiceChip(
                      label: Text(cond.label),
                      selected: isSelected,
                      onSelected: (_) => setState(
                        () => _selectedCondition = isSelected ? null : cond,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Price Range ───────────────────────────────────────────────
              Text(
                'Price Range (₹)',
                style: AppTypography.titleSmall.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min Price',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Price',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Apply Button ──────────────────────────────────────────────
              AppButton(
                text: 'Apply Filters',
                onPressed: _apply,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String value, String label) {
    final isSelected = _selectedSortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedSortBy = value);
      },
    );
  }
}

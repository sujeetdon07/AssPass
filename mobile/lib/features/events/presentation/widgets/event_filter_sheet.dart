import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/event_category.dart';

/// Bottom sheet modal to filter events by timeframe and category.
class EventFilterSheet extends StatefulWidget {
  const EventFilterSheet({
    super.key,
    required this.selectedTimeframe,
    required this.selectedCategory,
    required this.onApply,
  });

  final String selectedTimeframe;
  final EventCategory? selectedCategory;
  final void Function(String timeframe, EventCategory? category) onApply;

  @override
  State<EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<EventFilterSheet> {
  late String _timeframe;
  late EventCategory? _category;

  @override
  void initState() {
    super.initState();
    _timeframe = widget.selectedTimeframe;
    _category = widget.selectedCategory;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        borderRadius: AppRadius.bottomSheet,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Events',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _timeframe = 'upcoming';
                      _category = null;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Timeframe Section
            Text(
              'Timeframe',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate300 : AppColors.slate700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                _buildChoiceChip('upcoming', 'Upcoming'),
                _buildChoiceChip('weekend', 'This Weekend'),
                _buildChoiceChip('past', 'Past Events'),
                _buildChoiceChip('all', 'All Events'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Category Section
            Text(
              'Category',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate300 : AppColors.slate700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('All Categories'),
                  selected: _category == null,
                  onSelected: (selected) {
                    if (selected) setState(() => _category = null);
                  },
                ),
                ...EventCategory.values.map((cat) {
                  return ChoiceChip(
                    avatar: Icon(cat.icon, size: 16),
                    label: Text(cat.label),
                    selected: _category == cat,
                    onSelected: (selected) {
                      setState(() {
                        _category = selected ? cat : null;
                      });
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(_timeframe, _category);
                  Navigator.of(context).pop();
                },
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _timeframe == value,
      onSelected: (selected) {
        if (selected) {
          setState(() => _timeframe = value);
        }
      },
    );
  }
}

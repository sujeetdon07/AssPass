import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/chips/app_chip.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../application/services_controller.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_filter.dart';
import '../widgets/service_card.dart';
import '../widgets/service_filter_sheet.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      ref.read(servicesControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openFilterSheet() async {
    final currentFilter = ref.read(servicesControllerProvider).filter;
    final updated = await ServiceFilterSheet.show(
      context,
      initialFilter: currentFilter,
    );
    if (updated != null) {
      ref.read(servicesControllerProvider.notifier).setFilter(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(servicesControllerProvider);
    final notifier = ref.read(servicesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Local Services',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              state.filter.hasActiveFilters ? AppIcons.filter : AppIcons.filter,
              color: state.filter.hasActiveFilters ? AppColors.indigo600 : null,
            ),
            tooltip: 'Filter services',
            onPressed: _openFilterSheet,
          ),
          IconButton(
            icon: const Icon(AppIcons.service),
            tooltip: 'My Services',
            onPressed: () => context.push('/services/my-services'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.loadServices(isRefresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Search & Filter Bar ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search electricians, plumbers, tutors, cleaners...',
                    prefixIcon: const Icon(AppIcons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(AppIcons.close, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              notifier.setSearchQuery(null);
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
                  onSubmitted: (query) => notifier.setSearchQuery(query),
                  onChanged: (text) {
                    if (text.isEmpty) notifier.setSearchQuery(null);
                  },
                ),
              ),
            ),

            // ── Horizontal Category Chips ────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: ServiceCategory.values.length + 1,
                  separatorBuilder: (context, index) => AppSpacing.gapHXs,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isAllSelected = state.filter.category == null;
                      return AppChip(
                        label: 'All',
                        isSelected: isAllSelected,
                        onSelected: (_) => notifier.setCategory(null),
                      );
                    }
                    final cat = ServiceCategory.values[index - 1];
                    final isSelected = state.filter.category == cat;
                    return AppChip(
                      label: cat.label,
                      icon: cat.icon,
                      isSelected: isSelected,
                      onSelected: (selected) {
                        notifier.setCategory(selected ? cat : null);
                      },
                    );
                  },
                ),
              ),
            ),

            // ── Active Filter Bar (if filters active) ────────────────────────
            if (state.filter.hasActiveFilters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Filtered by: ',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      if (state.filter.pricingModel != null) ...[
                        Chip(
                          label: Text(state.filter.pricingModel!.label),
                          visualDensity: VisualDensity.compact,
                        ),
                        AppSpacing.gapHXs,
                      ],
                      if (state.filter.radiusKm != null) ...[
                        Chip(
                          label: Text('${state.filter.radiusKm!.toInt()} km'),
                          visualDensity: VisualDensity.compact,
                        ),
                        AppSpacing.gapHXs,
                      ],
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          notifier.setFilter(const ServiceFilter());
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Content Area: Loading / Error / Empty / List ─────────────────
            if (state.isLoading)
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainer
                              : AppColors.lightSurfaceContainer,
                          borderRadius: AppRadius.borderMd,
                        ),
                        child: const AppSkeleton(
                            width: double.infinity, height: 160,),
                      ),
                    ),
                    childCount: 4,
                  ),
                ),
              )
            else if (state.errorMessage != null && state.services.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: AppErrorState(
                    title: 'Unable to Load Services',
                    message: state.errorMessage!,
                    onRetry: () => notifier.loadServices(isRefresh: true),
                  ),
                ),
              )
            else if (state.services.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: AppEmptyState(
                    title: 'No Services Found',
                    description: state.filter.hasActiveFilters
                        ? 'Try clearing some filters or expanding your search area.'
                        : 'No local service providers listed in this neighborhood yet. Offer your skills today!',
                    actionText: state.filter.hasActiveFilters
                        ? 'Reset Filters'
                        : 'Offer a Service',
                    onAction: () {
                      if (state.filter.hasActiveFilters) {
                        _searchController.clear();
                        notifier.setFilter(const ServiceFilter());
                      } else {
                        context.push('/services/create');
                      }
                    },
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < state.services.length) {
                        final service = state.services[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: ServiceCard(
                            service: service,
                            onFavoriteToggle: () =>
                                notifier.toggleFavorite(service.id),
                          ),
                        );
                      }
                      if (state.isLoadingMore) {
                        return const Center(
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    childCount:
                        state.services.length + (state.isLoadingMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/services/create'),
        icon: const Icon(AppIcons.add),
        label: const Text('Offer Service'),
        backgroundColor: AppColors.indigo600,
        foregroundColor: AppColors.pureWhite,
      ),
    );
  }
}

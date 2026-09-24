import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../../nearby/application/location_controller.dart';
import '../../../nearby/domain/entities/location_state.dart';
import '../../application/marketplace_controller.dart';
import '../../domain/entities/marketplace_category.dart';
import '../widgets/listing_card.dart';
import '../widgets/marketplace_filter_sheet.dart';

/// Production-grade Marketplace Discovery screen for Aaspaas.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final locState = ref.read(locationControllerProvider);
    double? lat;
    double? lng;
    if (locState is LocationReady) {
      lat = locState.latitude;
      lng = locState.longitude;
    } else if (locState is LocationManualLocality) {
      lat = locState.latitude;
      lng = locState.longitude;
    }

    ref.read(marketplaceControllerProvider.notifier).loadListings(
          refresh: true,
          latitude: lat,
          longitude: lng,
        );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final locState = ref.read(locationControllerProvider);
      double? lat;
      double? lng;
      if (locState is LocationReady) {
        lat = locState.latitude;
        lng = locState.longitude;
      } else if (locState is LocationManualLocality) {
        lat = locState.latitude;
        lng = locState.longitude;
      }

      ref.read(marketplaceControllerProvider.notifier).loadMore(
            latitude: lat,
            longitude: lng,
          );
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      final locState = ref.read(locationControllerProvider);
      double? lat;
      double? lng;
      if (locState is LocationReady) {
        lat = locState.latitude;
        lng = locState.longitude;
      } else if (locState is LocationManualLocality) {
        lat = locState.latitude;
        lng = locState.longitude;
      }

      ref.read(marketplaceControllerProvider.notifier).setSearchQuery(
            query,
            latitude: lat,
            longitude: lng,
          );
    });
  }

  void _openFilterSheet() {
    final state = ref.read(marketplaceControllerProvider);
    final locState = ref.read(locationControllerProvider);
    double? lat;
    double? lng;
    if (locState is LocationReady) {
      lat = locState.latitude;
      lng = locState.longitude;
    } else if (locState is LocationManualLocality) {
      lat = locState.latitude;
      lng = locState.longitude;
    }

    MarketplaceFilterSheet.show(
      context: context,
      currentFilter: state.filter,
      onApply: (filter) {
        ref.read(marketplaceControllerProvider.notifier).setFilter(
              filter,
              latitude: lat,
              longitude: lng,
            );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(marketplaceControllerProvider);
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    final locState = ref.watch(locationControllerProvider);
    double? activeLat;
    double? activeLng;
    if (locState is LocationReady) {
      activeLat = locState.latitude;
      activeLng = locState.longitude;
    } else if (locState is LocationManualLocality) {
      activeLat = locState.latitude;
      activeLng = locState.longitude;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Marketplace',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, size: 22),
            tooltip: 'My Listings',
            onPressed: () => context.push('/marketplace/my-listings'),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(AppIcons.filter, size: 22),
                tooltip: 'Filters',
                onPressed: _openFilterSheet,
              ),
              if (state.filter.hasActiveFilters)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/marketplace/create'),
        icon: const Icon(AppIcons.add, size: 20),
        label: const Text('Sell Item'),
        backgroundColor: primaryColor,
        foregroundColor:
            isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary,
      ),
      body: ResponsiveContainer(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            await ref.read(marketplaceControllerProvider.notifier).loadListings(
                  refresh: true,
                  latitude: activeLat,
                  longitude: activeLng,
                );
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Search & Discovery Bar ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search furniture, mobiles, books...',
                      prefixIcon: const Icon(AppIcons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(AppIcons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.slate100,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.input,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Categories Horizontal Filter ──────────────────────────────
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: FilterChip(
                          label: const Text('All Items'),
                          selected: state.filter.category == null,
                          onSelected: (_) {
                            ref
                                .read(marketplaceControllerProvider.notifier)
                                .setCategory(
                                  null,
                                  latitude: activeLat,
                                  longitude: activeLng,
                                );
                          },
                        ),
                      ),
                      ...MarketplaceCategory.values.map((cat) {
                        final isSelected = state.filter.category == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: FilterChip(
                            avatar: Icon(cat.icon, size: 16),
                            label: Text(cat.label),
                            selected: isSelected,
                            onSelected: (_) {
                              ref
                                  .read(marketplaceControllerProvider.notifier)
                                  .setCategory(
                                    isSelected ? null : cat,
                                    latitude: activeLat,
                                    longitude: activeLng,
                                  );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.sm),
              ),

              // ── State Handling: Loading, Error, Empty, or Listings Grid ───
              if (state.isLoading)
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const AppSkeleton(
                        height: 220,
                        borderRadius: AppRadius.card,
                      ),
                      childCount: 6,
                    ),
                  ),
                )
              else if (state.errorMessage != null && state.listings.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorState(
                    message: state.errorMessage!,
                    onRetry: () {
                      ref
                          .read(marketplaceControllerProvider.notifier)
                          .loadListings(
                            refresh: true,
                            latitude: activeLat,
                            longitude: activeLng,
                          );
                    },
                  ),
                )
              else if (state.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: AppEmptyState(
                      icon: AppIcons.marketplace,
                      title: 'No listings found',
                      description: state.filter.hasActiveFilters
                          ? 'No items matched your current filters. Try changing category, expanding radius, or resetting filters.'
                          : 'No items have been listed in this neighborhood yet. Be the first neighbor to sell or give away something!',
                      actionText: state.filter.hasActiveFilters
                          ? 'Reset Filters'
                          : 'List an Item',
                      onAction: () {
                        if (state.filter.hasActiveFilters) {
                          ref
                              .read(marketplaceControllerProvider.notifier)
                              .setFilter(
                                state.filter.clearAll(),
                                latitude: activeLat,
                                longitude: activeLng,
                              );
                        } else {
                          context.push('/marketplace/create');
                        }
                      },
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.70,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final listing = state.listings[index];
                        return ListingCard(
                          listing: listing,
                          onTap: () {
                            context.push('/marketplace/listings/${listing.id}');
                          },
                          onFavoritePressed: () {
                            ref
                                .read(marketplaceControllerProvider.notifier)
                                .toggleFavorite(listing.id);
                          },
                        );
                      },
                      childCount: state.listings.length,
                    ),
                  ),
                ),

              // ── Loading More Indicator ───────────────────────────────────
              if (state.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl + AppSpacing.md),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

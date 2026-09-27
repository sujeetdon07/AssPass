import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/favorites_controller.dart';
import '../../application/marketplace_controller.dart';
import '../widgets/listing_card.dart';

/// Screen displaying current user's saved/favorited marketplace listings.
class MyFavoritesScreen extends ConsumerStatefulWidget {
  const MyFavoritesScreen({super.key});

  @override
  ConsumerState<MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends ConsumerState<MyFavoritesScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(favoritesControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(favoritesControllerProvider);
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(AppRoutes.marketplace);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: canPop
              ? null
              : BackButton(
                  onPressed: () => context.go(AppRoutes.marketplace),
                ),
          title: Text(
            'My Favorites',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text(
                  '${state.listings.length}',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.rose500,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ResponsiveContainer(
          child: state.isLoading
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.70,
                    ),
                    itemCount: 4,
                    itemBuilder: (_, __) => const AppSkeleton(
                      height: 200,
                      borderRadius: AppRadius.card,
                    ),
                  ),
                )
              : state.errorMessage != null && state.listings.isEmpty
                  ? AppErrorState(
                      message: state.errorMessage!,
                      onRetry: () => ref
                          .read(favoritesControllerProvider.notifier)
                          .loadFavorites(refresh: true),
                    )
                  : state.listings.isEmpty
                      ? Center(
                          child: AppEmptyState(
                            icon: AppIcons.likeOutline,
                            title: 'No Favorites Yet',
                            description:
                                'Listings you save will appear here.',
                            actionText: 'Browse Marketplace',
                            onAction: () {
                              if (canPop) {
                                Navigator.of(context).pop();
                              } else {
                                context.go(AppRoutes.marketplace);
                              }
                            },
                          ),
                        )
                      : RefreshIndicator(
                          color: primaryColor,
                          onRefresh: () async {
                            await ref
                                .read(favoritesControllerProvider.notifier)
                                .loadFavorites(refresh: true);
                          },
                          child: GridView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 0.70,
                            ),
                            itemCount: state.listings.length,
                            itemBuilder: (context, index) {
                              final listing = state.listings[index];
                              return ListingCard(
                                listing: listing,
                                onTap: () async {
                                  await context.push(
                                    '/marketplace/listings/${listing.id}',
                                  );
                                  // Refresh favorites on return in case status/favorite changed
                                  ref
                                      .read(
                                        favoritesControllerProvider.notifier,
                                      )
                                      .loadFavorites(refresh: true);
                                },
                                onFavoritePressed: () {
                                  ref
                                      .read(
                                        favoritesControllerProvider.notifier,
                                      )
                                      .unfavorite(listing.id);
                                  ref
                                      .read(
                                        marketplaceControllerProvider.notifier,
                                      )
                                      .toggleFavorite(listing.id);
                                },
                              );
                            },
                          ),
                        ),
        ),
      ),
    );
  }
}

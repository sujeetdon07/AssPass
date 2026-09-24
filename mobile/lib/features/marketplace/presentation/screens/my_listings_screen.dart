import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/my_listings_controller.dart';
import '../../domain/entities/marketplace_status.dart';
import '../widgets/listing_card.dart';

/// Screen for managing current user's listings across status tabs.
class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<MarketplaceListingStatus?> _tabStatuses = [
    null, // All
    MarketplaceListingStatus.active,
    MarketplaceListingStatus.sold,
    MarketplaceListingStatus.archived,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final status = _tabStatuses[_tabController.index];
        ref.read(myListingsControllerProvider.notifier).filterByStatus(status);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(myListingsControllerProvider);
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Sold'),
            Tab(text: 'Archived'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/marketplace/create'),
        icon: const Icon(AppIcons.add, size: 20),
        label: const Text('Sell Item'),
      ),
      body: ResponsiveContainer(
        child: state.isLoading
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
            : state.listings.isEmpty
                ? Center(
                    child: AppEmptyState(
                      icon: AppIcons.marketplace,
                      title: 'No listings in this view',
                      description:
                          'You have no items listed in this tab. Start selling to connect with local buyers.',
                      actionText: 'List an Item',
                      onAction: () => context.push('/marketplace/create'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      final status = _tabStatuses[_tabController.index];
                      await ref
                          .read(myListingsControllerProvider.notifier)
                          .loadMyListings(status: status);
                    },
                    child: GridView.builder(
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
                          onTap: () {
                            context.push('/marketplace/listings/${listing.id}');
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

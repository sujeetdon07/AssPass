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
import '../../application/my_businesses_controller.dart';
import '../../domain/entities/business_entity.dart';
import '../widgets/business_card.dart';

/// Screen for managing the current user's registered local businesses.
class MyBusinessesScreen extends ConsumerStatefulWidget {
  const MyBusinessesScreen({super.key});

  @override
  ConsumerState<MyBusinessesScreen> createState() => _MyBusinessesScreenState();
}

class _MyBusinessesScreenState extends ConsumerState<MyBusinessesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<BusinessStatus?> _tabStatuses = [
    null, // All
    BusinessStatus.active,
    BusinessStatus.inactive,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final status = _tabStatuses[_tabController.index];
        ref
            .read(myBusinessesControllerProvider.notifier)
            .filterByStatus(status);
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
    final state = ref.watch(myBusinessesControllerProvider);
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Businesses'),
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
            Tab(text: 'Inactive'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/businesses/create'),
        icon: const Icon(AppIcons.add, size: 20),
        label: const Text('Add Business'),
      ),
      body: ResponsiveContainer(
        child: state.isLoading
            ? ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppSkeleton(
                    height: 120,
                    borderRadius: AppRadius.card,
                  ),
                ),
              )
            : state.businesses.isEmpty
                ? Center(
                    child: AppEmptyState(
                      icon: AppIcons.business,
                      title: 'No businesses listed',
                      description:
                          'You have not registered any businesses in this category yet. Reach thousands of local neighbors by registering your shop or enterprise.',
                      actionText: 'Register Business',
                      onAction: () => context.push('/businesses/create'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      final status = _tabStatuses[_tabController.index];
                      await ref
                          .read(myBusinessesControllerProvider.notifier)
                          .loadMyBusinesses(status: status);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: state.businesses.length,
                      itemBuilder: (context, index) {
                        final business = state.businesses[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: BusinessCard(
                            business: business,
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

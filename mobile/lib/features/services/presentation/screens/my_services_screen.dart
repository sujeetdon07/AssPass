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
import '../../application/my_services_controller.dart';
import '../../domain/entities/service_category.dart';
import '../widgets/service_card.dart';

/// Screen for managing the current user's registered local services.
class MyServicesScreen extends ConsumerStatefulWidget {
  const MyServicesScreen({super.key});

  @override
  ConsumerState<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends ConsumerState<MyServicesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<ServiceStatus?> _tabStatuses = [
    null, // All
    ServiceStatus.active,
    ServiceStatus.inactive,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final status = _tabStatuses[_tabController.index];
        ref.read(myServicesControllerProvider.notifier).filterByStatus(status);
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
    final state = ref.watch(myServicesControllerProvider);
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Services'),
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
        onPressed: () => context.push('/services/create'),
        icon: const Icon(AppIcons.add, size: 20),
        label: const Text('Offer Service'),
      ),
      body: ResponsiveContainer(
        child: state.isLoading
            ? ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppSkeleton(
                    height: 140,
                    borderRadius: AppRadius.card,
                  ),
                ),
              )
            : state.services.isEmpty
                ? Center(
                    child: AppEmptyState(
                      icon: AppIcons.service,
                      title: 'No services offered yet',
                      description:
                          'Share your skills and trade with neighbors. Plumbers, tutors, electricians, and more can list their services here.',
                      actionText: 'Offer a Service',
                      onAction: () => context.push('/services/create'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      final status = _tabStatuses[_tabController.index];
                      await ref
                          .read(myServicesControllerProvider.notifier)
                          .loadMyServices(status: status);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: state.services.length,
                      itemBuilder: (context, index) {
                        final service = state.services[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: ServiceCard(
                            service: service,
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

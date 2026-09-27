import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/chips/app_badge.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/report_history_controller.dart';
import '../../domain/models/safety_enums.dart';
import '../../domain/models/safety_report_item.dart';

/// Screen displaying the current user's submitted safety reports.
///
/// Complies with Phase 10 privacy requirements: only exposes the user's
/// own submitted reports, targets, reasons, and high-level status.
class ReportHistoryScreen extends ConsumerStatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  ConsumerState<ReportHistoryScreen> createState() =>
      _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends ConsumerState<ReportHistoryScreen> {
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
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(reportHistoryControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(reportHistoryControllerProvider);
    final canPop = Navigator.canPop(context);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(AppRoutes.profile);
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Text(
            'Report History',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: const Icon(AppIcons.back),
            onPressed: () => canPop
                ? Navigator.of(context).pop()
                : context.go(AppRoutes.profile),
          ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: ResponsiveContainer(
        child: Builder(
          builder: (context) {
            if (state.isLoading) {
              return ListView.separated(
                padding: AppSpacing.screenPadding,
                itemCount: 4,
                separatorBuilder: (_, __) => AppSpacing.gapVSm,
                itemBuilder: (_, __) => const AppSkeleton(
                  width: double.infinity,
                  height: 90,
                  borderRadius: AppRadius.borderMd,
                ),
              );
            }

            if (state.hasError) {
              return AppErrorState(
                message: state.error ?? 'Something went wrong.',
                onRetry: () =>
                    ref.read(reportHistoryControllerProvider.notifier).load(),
              );
            }

            if (state.items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.shield_outlined,
                title: 'No Reports Submitted',
                description:
                    'When you report content or accounts that violate community guidelines, '
                    'you can track the status of your reports here.',
              );
            }

            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(reportHistoryControllerProvider.notifier).load(),
              child: ListView.separated(
                controller: _scrollController,
                padding: AppSpacing.screenPadding,
                itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => AppSpacing.gapVSm,
                itemBuilder: (context, index) {
                  if (index >= state.items.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final item = state.items[index];
                  return _ReportCard(item: item, isDark: isDark);
                },
              ),
            );
          },
        ),
      ),
    ),
  );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.item,
    required this.isDark,
  });

  final SafetyReportItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Target type badge
              AppBadge(
                label: item.targetType.label,
                variant: AppBadgeVariant.neutral,
              ),
              const Spacer(),
              // Status chip
              _StatusBadge(status: item.status),
            ],
          ),
          AppSpacing.gapVSm,
          Text(
            item.reason.label,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          if (item.details != null && item.details!.isNotEmpty) ...[
            AppSpacing.gapVXs,
            Text(
              item.details!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
          AppSpacing.gapVSm,
          Text(
            _formatDate(item.createdAt),
            style: AppTypography.labelSmall.copyWith(
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    AppBadgeVariant variant;
    switch (status) {
      case ReportStatus.pending:
        variant = AppBadgeVariant.warning;
        break;
      case ReportStatus.reviewing:
        variant = AppBadgeVariant.primary;
        break;
      case ReportStatus.actioned:
        variant = AppBadgeVariant.success;
        break;
      case ReportStatus.dismissed:
      case ReportStatus.duplicate:
        variant = AppBadgeVariant.neutral;
        break;
    }

    return AppBadge(
      label: status.label,
      variant: variant,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/listing_detail_controller.dart';
import '../../application/marketplace_controller.dart';
import '../../domain/entities/marketplace_listing_entity.dart';
import '../../domain/entities/marketplace_status.dart';
import '../widgets/listing_status_chip.dart';
import '../widgets/report_listing_dialog.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/media/app_cached_image.dart';
import '../../../../core/services/app_share_service.dart';
import '../../../messaging/domain/repositories/messaging_repository.dart';

/// Detailed view of an individual marketplace listing.
class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({
    super.key,
    required this.listingId,
  });

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  int _activeImageIndex = 0;

  void _onReport() {
    ReportListingDialog.show(
      context,
      onSubmit: (reason, details) async {
        final success = await ref
            .read(listingDetailControllerProvider(widget.listingId).notifier)
            .reportListing(reason: reason, details: details);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Thank you. Your report has been submitted for review.'),
            ),
          );
        }
        return success;
      },
    );
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text(
          'Are you sure you want to delete this listing? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ref
                  .read(
                    listingDetailControllerProvider(widget.listingId).notifier,
                  )
                  .deleteListing();
              if (ok && mounted) {
                ref
                    .read(marketplaceControllerProvider.notifier)
                    .loadListings(refresh: true);
                context.pop();
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.rose500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsSold() async {
    final ok = await ref
        .read(listingDetailControllerProvider(widget.listingId).notifier)
        .updateStatus(MarketplaceListingStatus.sold);
    if (ok && mounted) {
      ref
          .read(marketplaceControllerProvider.notifier)
          .loadListings(refresh: true);
      AppSnackbar.showSuccess(context, message: 'Listing marked as sold.');
    }
  }

  Future<void> _relistAsActive() async {
    final ok = await ref
        .read(listingDetailControllerProvider(widget.listingId).notifier)
        .updateStatus(MarketplaceListingStatus.active);
    if (ok && mounted) {
      ref
          .read(marketplaceControllerProvider.notifier)
          .loadListings(refresh: true);
      AppSnackbar.showSuccess(context, message: 'Listing relisted as active.');
    }
  }

  void _confirmArchive() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Listing'),
        content: const Text(
          'Archiving will hide this listing from the marketplace. You can restore it anytime from My Listings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ref
                  .read(
                    listingDetailControllerProvider(widget.listingId).notifier,
                  )
                  .updateStatus(MarketplaceListingStatus.archived);
              if (ok && mounted) {
                ref
                    .read(marketplaceControllerProvider.notifier)
                    .loadListings(refresh: true);
                AppSnackbar.showSuccess(
                  context,
                  message: 'Listing archived successfully.',
                );
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _confirmRestore() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Listing'),
        content: const Text(
          'Restoring will make this listing visible in the marketplace again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ref
                  .read(
                    listingDetailControllerProvider(widget.listingId).notifier,
                  )
                  .updateStatus(MarketplaceListingStatus.active);
              if (ok && mounted) {
                ref
                    .read(marketplaceControllerProvider.notifier)
                    .loadListings(refresh: true);
                AppSnackbar.showSuccess(
                  context,
                  message: 'Listing restored to Active.',
                );
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _contactSeller() async {
    final listing =
        ref.read(listingDetailControllerProvider(widget.listingId)).listing;
    if (listing == null) return;

    if (listing.isOwner) {
      AppSnackbar.showInfo(context, message: 'This is your own listing.');
      return;
    }

    try {
      final repo = ref.read(messagingRepositoryProvider);
      final conversation =
          await repo.createOrGetConversation(listing.seller.id);
      if (mounted) {
        context.push('/messages/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Unable to start conversation with seller.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(listingDetailControllerProvider(widget.listingId));
    final listing = state.listing;

    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor =
        isDark ? AppColors.darkOutlineVariant : AppColors.lightOutlineVariant;
    final canPop = Navigator.canPop(context);

    if (state.isLoading) {
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
          ),
          body: const ResponsiveContainer(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(height: 250, borderRadius: AppRadius.card),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 28, width: 140),
                  SizedBox(height: AppSpacing.sm),
                  AppSkeleton(height: 20, width: double.infinity),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 100, borderRadius: AppRadius.card),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (state.errorMessage != null || listing == null) {
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
          ),
          body: ResponsiveContainer(
            child: AppErrorState(
              message: state.errorMessage ?? 'Listing not found.',
              onRetry: () {
                ref
                    .read(
                      listingDetailControllerProvider(widget.listingId).notifier,
                    )
                    .loadListing();
              },
            ),
          ),
        ),
      );
    }

    final hasImages = listing.images.isNotEmpty;

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
            listing.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share listing',
            onPressed: () => AppShareService.shareMarketplace(context, listing),
          ),
          IconButton(
            icon: Icon(
              listing.isFavorited ? AppIcons.like : AppIcons.likeOutline,
              color: listing.isFavorited ? AppColors.rose500 : null,
            ),
            tooltip: listing.isFavorited ? 'Unfavorite' : 'Favorite',
            onPressed: () {
              ref
                  .read(
                    listingDetailControllerProvider(widget.listingId).notifier,
                  )
                  .toggleFavorite();
              ref
                  .read(marketplaceControllerProvider.notifier)
                  .toggleFavorite(widget.listingId);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more),
            onSelected: (val) {
              if (val == 'share') {
                AppShareService.shareMarketplace(context, listing);
              }
              if (val == 'send_in_aaspaas') {
                AppShareService.showSendInAaspaasSheet(
                  context,
                  AppShareService.buildMarketplacePayload(listing),
                );
              }
              if (val == 'report') _onReport();
              if (val == 'edit') {
                context.push(
                  '/marketplace/listings/${listing.id}/edit',
                  extra: listing,
                );
              }
              if (val == 'mark_sold') _markAsSold();
              if (val == 'relist') _relistAsActive();
              if (val == 'archive') _confirmArchive();
              if (val == 'restore') _confirmRestore();
              if (val == 'delete') _confirmDelete();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 18),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Share via...', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'send_in_aaspaas',
                child: Row(
                  children: [
                    Icon(Icons.send_rounded, size: 18, color: Color(0xFF4F46E5)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Send in Aaspaas', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              if (listing.isOwner) ...[
                if (listing.isActive) ...[
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(AppIcons.edit, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text('Edit Listing', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'mark_sold',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text('Mark as Sold', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text('Archive Listing', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(AppIcons.delete, size: 18, color: AppColors.rose500),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Delete Listing',
                            style: TextStyle(color: AppColors.rose500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (listing.isSold) ...[
                  const PopupMenuItem(
                    value: 'relist',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text('Mark as Active / Relist', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text('Archive Listing', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(AppIcons.delete, size: 18, color: AppColors.rose500),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Delete Listing',
                            style: TextStyle(color: AppColors.rose500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const PopupMenuItem(
                    value: 'restore',
                    child: Row(
                      children: [
                        Icon(Icons.unarchive_outlined, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text('Restore / Unarchive Listing', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(AppIcons.delete, size: 18, color: AppColors.rose500),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Delete Listing',
                            style: TextStyle(color: AppColors.rose500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(AppIcons.report, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text('Report Listing', overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: listing.isOwner
              ? _buildOwnerActions(listing, primaryColor)
              : _buildBuyerActions(),
        ),
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Media / Gallery Area ─────────────────────────────────────
              if (hasImages)
                SizedBox(
                  height: 280,
                  child: Stack(
                    children: [
                      PageView.builder(
                        itemCount: listing.images.length,
                        onPageChanged: (i) =>
                            setState(() => _activeImageIndex = i),
                        itemBuilder: (context, index) {
                          return AppCachedImage(
                            imageUrl: listing.images[index].url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        },
                      ),
                      if (listing.images.length > 1)
                        Positioned(
                          bottom: AppSpacing.sm,
                          right: AppSpacing.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.pureBlack.withValues(alpha: 0.65),
                              borderRadius: AppRadius.borderPill,
                            ),
                            child: Text(
                              '${_activeImageIndex + 1} / ${listing.images.length}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Container(
                  height: 180,
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.indigo50,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        listing.category.icon,
                        size: 56,
                        color:
                            isDark ? AppColors.indigo300 : AppColors.indigo500,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        listing.category.label,
                        style: AppTypography.titleSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Status Banner (if Sold or Archived) ──────────────────────
              if (!listing.isActive)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  color:
                      listing.isSold ? AppColors.slate800 : AppColors.amber700,
                  child: Text(
                    listing.isSold
                        ? 'This item has been marked as SOLD by the seller.'
                        : 'This listing is currently ARCHIVED.',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.pureWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price & Condition Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          listing.formattedPrice,
                          style: AppTypography.headlineMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: listing.isFree
                                ? AppColors.emerald500
                                : primaryColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceVariant
                                : AppColors.indigo50,
                            borderRadius: AppRadius.borderSm,
                          ),
                          child: Text(
                            listing.condition.label,
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.indigo300
                                  : AppColors.indigo700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ListingStatusChip(status: listing.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Title
                    Text(
                      listing.title,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Locality & Distance Pill
                    Row(
                      children: [
                        Icon(
                          AppIcons.location,
                          size: 16,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          listing.locationSummary,
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (listing.distance != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '•  ${listing.distance}',
                            style: AppTypography.bodySmall.copyWith(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    const Divider(),
                    const SizedBox(height: AppSpacing.md),

                    // ── Description ─────────────────────────────────────────
                    Text(
                      'Description',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      listing.description,
                      style: AppTypography.bodyMedium.copyWith(
                        height: 1.5,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    const Divider(),
                    const SizedBox(height: AppSpacing.md),

                    // ── Seller Profile Projection (Privacy-Safe) ─────────────
                    Text(
                      'Seller Information',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: AppRadius.card,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            name: listing.seller.displayName,
                            imageUrl: listing.seller.avatarUrl,
                            size: AppAvatarSize.s48,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listing.seller.displayName,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  listing.seller.locality != null
                                      ? 'Verified resident • ${listing.seller.locality}'
                                      : 'Verified neighbor',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildBuyerActions() {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            text: 'Contact Seller',
            prefixIcon: AppIcons.comment,
            onPressed: _contactSeller,
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerActions(
    MarketplaceListingEntity listing,
    Color primaryColor,
  ) {
    return Row(
      children: [
        if (listing.isActive) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _markAsSold,
              child: const Text('Mark as Sold'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              text: 'Edit Listing',
              onPressed: () {
                context.push(
                  '/marketplace/listings/${listing.id}/edit',
                  extra: listing,
                );
              },
            ),
          ),
        ] else if (listing.isSold) ...[
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Archive'),
              onPressed: _confirmArchive,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              text: 'Relist as Active',
              onPressed: _relistAsActive,
            ),
          ),
        ] else ...[
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(AppIcons.delete, size: 18, color: AppColors.rose500),
              label: const Text(
                'Delete',
                style: TextStyle(color: AppColors.rose500),
              ),
              onPressed: _confirmDelete,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              text: 'Restore Listing',
              onPressed: _confirmRestore,
            ),
          ),
        ],
      ],
    );
  }
}

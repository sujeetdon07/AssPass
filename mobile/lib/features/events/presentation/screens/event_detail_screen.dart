import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/event_detail_controller.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/entities/event_rsvp_status.dart';

/// Full screen details view for a specific event.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.initialEvent,
  });

  final String eventId;
  final EventEntity? initialEvent;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialEvent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(eventDetailControllerProvider(widget.eventId).notifier)
            .setInitialEvent(widget.initialEvent!);
      });
    }
  }

  void _showCancelDialog() {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this event? All attendees will be notified.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation (optional)',
                hintText: 'e.g. Unforeseen weather conditions',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Event'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose700),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(eventDetailControllerProvider(widget.eventId).notifier)
                  .cancelEvent(reason: reasonController.text.trim());
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event cancelled successfully.')),
                );
              }
            },
            child: const Text('Cancel Event'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final detailsController = TextEditingController();
    String selectedReason = 'spam';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you reporting this event?'),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('Spam / Commercial')),
                  DropdownMenuItem(value: 'harassment', child: Text('Harassment / Abuse')),
                  DropdownMenuItem(value: 'scam_or_fraud', child: Text('Scam or Fraud')),
                  DropdownMenuItem(value: 'inappropriate_content', child: Text('Inappropriate Content')),
                  DropdownMenuItem(value: 'illegal_activity', child: Text('Illegal Activity')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedReason = val);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  hintText: 'Describe the issue...',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();
                final success = await ref
                    .read(eventDetailControllerProvider(widget.eventId).notifier)
                    .reportEvent(
                      selectedReason,
                      details: detailsController.text.trim(),
                    );
                if (!mounted) return;
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Thank you. Your report has been submitted.'),
                    ),
                  );
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventDetailControllerProvider(widget.eventId));
    final controller =
        ref.read(eventDetailControllerProvider(widget.eventId).notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final event = state.event;

    final canPop = Navigator.canPop(context);

    if (state.isLoading && event == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (event == null) {
      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          context.go(AppRoutes.events);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: canPop
                ? null
                : BackButton(
                    onPressed: () => context.go(AppRoutes.events),
                  ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Event not found or has been removed.'),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonal(
                  onPressed: () => controller.loadEvent(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final dateStr = dateFormat.format(event.startAt);
    final startStr = timeFormat.format(event.startAt);
    final endStr = timeFormat.format(event.endAt);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(AppRoutes.events);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: canPop
              ? null
              : BackButton(
                  onPressed: () => context.go(AppRoutes.events),
                ),
          title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report event',
            onPressed: _showReportDialog,
          ),
          if (event.isOrganizer && !event.isCancelled)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  context.push('/events/${event.id}/edit', extra: event);
                } else if (val == 'cancel') {
                  _showCancelDialog();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      Text('Edit Event'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 18, color: AppColors.rose700),
                      SizedBox(width: AppSpacing.sm),
                      Text('Cancel Event', style: TextStyle(color: AppColors.rose700)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Banner or Category Header
            if (event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty)
              Image.network(
                event.coverImageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildCategoryHeader(event, isDark),
              )
            else
              _buildCategoryHeader(event, isDark),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cancelled Alert Banner
                  if (event.isCancelled)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.rose900.withValues(alpha: 0.3) : AppColors.rose50,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(
                          color: isDark ? AppColors.rose700 : AppColors.rose100,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.rose700, size: 20),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'THIS EVENT HAS BEEN CANCELLED',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.rose700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (event.cancellationReason != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Reason: ${event.cancellationReason}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.slate300 : AppColors.slate700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Title & Category tag
                  Text(
                    event.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.indigo950 : AppColors.indigo50,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(event.category.icon, size: 14, color: AppColors.indigo600),
                            const SizedBox(width: 4),
                            Text(
                              event.category.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.indigo600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (event.community != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.slate100,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            event.community!.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark ? AppColors.slate300 : AppColors.slate700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Date and Time Box
                  _buildInfoTile(
                    icon: Icons.calendar_today_outlined,
                    title: dateStr,
                    subtitle: '$startStr – $endStr (${event.timezone})',
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Venue and Address Box
                  _buildInfoTile(
                    icon: Icons.location_on_outlined,
                    title: event.venue,
                    subtitle: event.address,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Description
                  Text(
                    'About this event',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    event.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: isDark ? AppColors.slate300 : AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Organizer Section
                  if (event.creator != null) ...[
                    Text(
                      'Host',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.indigo100,
                        backgroundImage: event.creator?.avatarUrl != null
                            ? NetworkImage(event.creator!.avatarUrl!)
                            : null,
                        child: event.creator?.avatarUrl == null
                            ? Text(
                                event.creator!.displayName.isNotEmpty
                                    ? event.creator!.displayName[0].toUpperCase()
                                    : 'O',
                                style: const TextStyle(color: AppColors.indigo700),
                              )
                            : null,
                      ),
                      title: Text(
                        event.creator!.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        event.creator?.locality ?? 'Neighbor',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Participants / Attendees Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attendees (${event.participantCount})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (state.participants.isNotEmpty)
                    Column(
                      children: state.participants.take(5).map((p) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.teal100,
                                child: Text(
                                  p.displayName.isNotEmpty
                                      ? p.displayName[0].toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.teal900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  p.displayName,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: p.status == EventRsvpStatus.going
                                      ? AppColors.teal50
                                      : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(AppRadius.xs),
                                ),
                                child: Text(
                                  p.status.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: p.status == EventRsvpStatus.going
                                        ? AppColors.teal600
                                        : AppColors.slate600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text(
                        'Be the first to join!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.slate400 : AppColors.slate600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 80), // Padding for sticky bottom RSVP bar
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom RSVP Action Bar
      bottomNavigationBar: event.isCancelled
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (event.isOrganizer)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/events/${event.id}/edit', extra: event),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Manage Event'),
                        ),
                      )
                    else ...[
                      // Going Button
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: state.isActionLoading
                              ? null
                              : () {
                                  if (event.isGoing) {
                                    controller.cancelRsvp();
                                  } else {
                                    controller.rsvp(EventRsvpStatus.going);
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: event.isGoing
                                ? AppColors.teal600
                                : AppColors.indigo600,
                          ),
                          icon: Icon(
                            event.isGoing
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                          ),
                          label: Text(event.isGoing ? 'Going' : 'RSVP Going'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      // Interested Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isActionLoading
                              ? null
                              : () {
                                  if (event.isInterested) {
                                    controller.cancelRsvp();
                                  } else {
                                    controller.rsvp(EventRsvpStatus.interested);
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: event.isInterested
                                ? AppColors.indigo600
                                : null,
                          ),
                          icon: Icon(
                            event.isInterested ? Icons.star : Icons.star_border,
                            size: 18,
                          ),
                          label: Text(event.isInterested ? 'Interested' : 'Interested'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildCategoryHeader(EventEntity event, bool isDark) {
    return Container(
      height: 120,
      width: double.infinity,
      color: isDark ? AppColors.indigo950 : AppColors.indigo50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(event.category.icon, size: 40, color: AppColors.indigo600),
            const SizedBox(height: 6),
            Text(
              event.category.label,
              style: const TextStyle(
                color: AppColors.indigo700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.slate50,
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.slate200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.indigo600),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

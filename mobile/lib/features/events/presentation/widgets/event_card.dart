import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/entities/event_rsvp_status.dart';

/// Reusable card displaying an Event in feeds, lists, and community pages.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.onRsvpTap,
  });

  final EventEntity event;
  final VoidCallback onTap;
  final ValueChanged<EventRsvpStatus>? onRsvpTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final monthFormat = DateFormat('MMM');
    final dayFormat = DateFormat('d');
    final timeFormat = DateFormat('h:mm a');

    final monthStr = monthFormat.format(event.startAt).toUpperCase();
    final dayStr = dayFormat.format(event.startAt);
    final timeStr = timeFormat.format(event.startAt);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.slate200,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Date Badge + Title & Category + Cancellation Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar Date Badge
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: event.isCancelled
                          ? (isDark ? AppColors.darkSurface : AppColors.slate100)
                          : (isDark ? AppColors.indigo950 : AppColors.indigo50),
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(
                        color: event.isCancelled
                            ? AppColors.slate300
                            : (isDark ? AppColors.indigo800 : AppColors.indigo200),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          monthStr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: event.isCancelled
                                ? AppColors.slate500
                                : AppColors.indigo600,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          dayStr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: event.isCancelled
                                ? AppColors.slate600
                                : (isDark ? AppColors.indigo300 : AppColors.indigo900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),

                  // Title + Category + Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.isCancelled)
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.rose900.withValues(alpha: 0.3) : AppColors.rose50,
                              borderRadius: AppRadius.borderXs,
                            ),
                            child: Text(
                              'CANCELLED',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.rose700,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        Text(
                          event.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: event.isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            Icon(
                              event.category.icon,
                              size: 14,
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                event.category.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text('•', style: TextStyle(color: isDark ? AppColors.slate500 : AppColors.slate400)),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              timeStr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.slate400 : AppColors.slate600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // Venue & Locality
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.locality != null
                          ? '${event.venue}, ${event.locality}'
                          : event.venue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (event.distanceMeters != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _formatDistance(event.distanceMeters!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.teal600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // Bottom Info Bar: Participants + Community Context + RSVP State
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Attendees count
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          size: 16,
                          color: isDark ? AppColors.slate400 : AppColors.slate600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${event.participantCount} going',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (event.community != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.slate100,
                                borderRadius: BorderRadius.circular(AppRadius.xs),
                              ),
                              child: Text(
                                event.community!.name,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // RSVP Status Badge or Quick RSVP button
                  if (event.userRsvpStatus != null && !event.isCancelled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: event.isGoing
                            ? (isDark ? AppColors.teal900.withValues(alpha: 0.3) : AppColors.teal50)
                            : (isDark ? AppColors.darkSurface : AppColors.slate100),
                        borderRadius: AppRadius.borderPill,
                        border: Border.all(
                          color: event.isGoing ? AppColors.teal600 : AppColors.slate300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            event.userRsvpStatus!.icon,
                            size: 14,
                            color: event.isGoing ? AppColors.teal600 : AppColors.slate600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.userRsvpStatus!.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: event.isGoing ? AppColors.teal600 : AppColors.slate700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!event.isCancelled && onRsvpTap != null)
                    InkWell(
                      onTap: () => onRsvpTap!(EventRsvpStatus.going),
                      borderRadius: AppRadius.chip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.indigo950 : AppColors.indigo50,
                          borderRadius: AppRadius.borderPill,
                          border: Border.all(
                            color: isDark ? AppColors.indigo800 : AppColors.indigo200,
                          ),
                        ),
                        child: Text(
                          'RSVP',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.indigo600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

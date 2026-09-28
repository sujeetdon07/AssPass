import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/feed/domain/entities/post_entity.dart';
import '../../features/marketplace/domain/entities/marketplace_listing_entity.dart';
import '../../features/events/domain/entities/event_entity.dart';
import '../../features/businesses/domain/entities/business_entity.dart';
import '../../features/services/domain/entities/service_listing_entity.dart';
import '../../features/communities/domain/entities/community_entity.dart';
import '../../features/messaging/application/conversation_controller.dart';
import '../../features/messaging/application/conversations_controller.dart';
import '../../shared/widgets/avatars/app_avatar.dart';
import '../../shared/widgets/feedback/app_empty_state.dart';
import '../../shared/widgets/feedback/app_snackbar.dart';

/// Categories of content that can be shared in Aaspaas.
enum ShareContentType {
  post,
  marketplace,
  event,
  business,
  service,
  community,
  profile,
  generic,
}

/// Structured payload for sharing content across the system.
class SharePayload {
  const SharePayload({
    required this.title,
    required this.text,
    required this.url,
    this.subject,
    this.contentType = ShareContentType.generic,
  });

  /// Short headline used for the Android Sharesheet preview (EXTRA_TITLE).
  final String title;

  /// Human-readable description/summary of the content.
  final String text;

  /// Canonical deep-link URL pointing to the content.
  final String url;

  /// Optional subject line (EXTRA_SUBJECT) for email/messaging targets.
  final String? subject;

  /// The category of content being shared.
  final ShareContentType contentType;

  /// Combined formatted text for Android Intent.EXTRA_TEXT.
  /// Android Sharesheet uses this as the text payload.
  String get formattedText {
    final buffer = StringBuffer();
    if (text.trim().isNotEmpty) {
      buffer.writeln(text.trim());
    }
    if (url.trim().isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(url.trim());
    }
    return buffer.toString().trim();
  }
}

/// Centralized service handling native Android Sharesheet (ACTION_SEND)
/// and optional in-app "Send in Aaspaas" conversation sharing.
class AppShareService {
  AppShareService._();

  /// Platform MethodChannel name matching Android MainActivity.
  static const String channelName = 'app.aaspaas/share';

  /// Channel instance exposed for testing/mocking.
  @visibleForTesting
  static MethodChannel channel = const MethodChannel(channelName);

  // ── Payload Builders ────────────────────────────────────────────────────────

  /// Builds a share payload for a Feed Post.
  static SharePayload buildPostPayload(PostEntity post) {
    final snippet = post.content.trim().isNotEmpty
        ? (post.content.length > 120
            ? '${post.content.substring(0, 117)}...'
            : post.content)
        : 'A local update from ${post.authorName}';

    final text = 'Check out this post on Aaspaas:\n\n$snippet';
    final url = '${AppConfig.shareBaseUrl}/feed/posts/${post.id}';

    return SharePayload(
      title: 'Post by ${post.authorName} on Aaspaas',
      text: text,
      url: url,
      subject: 'Post on Aaspaas by ${post.authorName}',
      contentType: ShareContentType.post,
    );
  }

  /// Builds a share payload for a Marketplace Listing.
  static SharePayload buildMarketplacePayload(MarketplaceListingEntity listing) {
    final priceStr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(listing.price);

    final text = 'Check out this listing on Aaspaas:\n\n${listing.title}\nPrice: $priceStr';
    final url = '${AppConfig.shareBaseUrl}/marketplace/listings/${listing.id}';

    return SharePayload(
      title: '${listing.title} on Aaspaas Marketplace',
      text: text,
      url: url,
      subject: 'Listing: ${listing.title}',
      contentType: ShareContentType.marketplace,
    );
  }

  /// Builds a share payload for an Event.
  static SharePayload buildEventPayload(EventEntity event) {
    final dateFormat = DateFormat('EEE, MMM d • h:mm a');
    final dateStr = dateFormat.format(event.startAt);

    final text = 'Check out this event on Aaspaas:\n\n${event.title}\n$dateStr';
    final url = '${AppConfig.shareBaseUrl}/events/${event.id}';

    return SharePayload(
      title: '${event.title} on Aaspaas',
      text: text,
      url: url,
      subject: 'Event: ${event.title}',
      contentType: ShareContentType.event,
    );
  }

  /// Builds a share payload for a Local Business.
  static SharePayload buildBusinessPayload(BusinessEntity business) {
    final categoryLabel = business.category.label;
    final categoryStr = categoryLabel.isNotEmpty ? '\nCategory: $categoryLabel' : '';
    final text = 'Check out this local business on Aaspaas:\n\n${business.name}$categoryStr';
    final url = '${AppConfig.shareBaseUrl}/businesses/${business.id}';

    return SharePayload(
      title: '${business.name} on Aaspaas',
      text: text,
      url: url,
      subject: 'Local Business: ${business.name}',
      contentType: ShareContentType.business,
    );
  }

  /// Builds a share payload for a Local Service.
  static SharePayload buildServicePayload(ServiceListingEntity service) {
    final priceStr = service.startingPrice != null
        ? '\nStarting at ${NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(service.startingPrice!)}'
        : '';

    final text = 'Check out this local service on Aaspaas:\n\n${service.title}$priceStr';
    final url = '${AppConfig.shareBaseUrl}/services/${service.id}';

    return SharePayload(
      title: '${service.title} on Aaspaas',
      text: text,
      url: url,
      subject: 'Service: ${service.title}',
      contentType: ShareContentType.service,
    );
  }

  /// Builds a share payload for a Community.
  static SharePayload buildCommunityPayload(CommunityEntity community) {
    final desc = community.description.trim().isNotEmpty
        ? '\n${community.description.trim()}'
        : '';
    final text = 'Check out this community on Aaspaas:\n\n${community.name}$desc';
    final url = '${AppConfig.shareBaseUrl}/communities/${community.id}';

    return SharePayload(
      title: '${community.name} on Aaspaas',
      text: text,
      url: url,
      subject: 'Community: ${community.name}',
      contentType: ShareContentType.community,
    );
  }

  /// Builds a share payload for a User Profile.
  static SharePayload buildProfilePayload({
    required String displayName,
    String? username,
    String? locality,
  }) {
    final cleanHandle = username != null && username.trim().isNotEmpty
        ? (username.trim().startsWith('@')
            ? username.trim()
            : '@${username.trim()}')
        : null;

    final buffer = StringBuffer();
    buffer.writeln('Check out $displayName on Aaspaas');
    if (cleanHandle != null) {
      buffer.writeln();
      buffer.writeln(cleanHandle);
    }
    if (locality != null && locality.trim().isNotEmpty) {
      buffer.writeln('📍 ${locality.trim()}');
    }

    final url = cleanHandle != null
        ? '${AppConfig.shareBaseUrl}/$cleanHandle'
        : '${AppConfig.shareBaseUrl}/profile';

    return SharePayload(
      title: '$displayName on Aaspaas',
      text: buffer.toString().trim(),
      url: url,
      subject: '$displayName on Aaspaas',
      contentType: ShareContentType.profile,
    );
  }

  // ── Native Android Sharing Execution ────────────────────────────────────────

  /// Invokes the native Android Sharesheet with ACTION_SEND and Intent.createChooser.
  ///
  /// If the platform channel is unavailable or fails, gracefully falls back to
  /// copying the share text to the clipboard and showing an informative message.
  static Future<bool> share(
    BuildContext context,
    SharePayload payload,
  ) async {
    final formattedText = payload.formattedText;
    if (formattedText.isEmpty) {
      if (context.mounted) {
        AppSnackbar.showError(
          context,
          message: 'Nothing to share.',
        );
      }
      return false;
    }

    try {
      final success = await channel.invokeMethod<bool>('share', {
        'title': payload.title,
        'text': formattedText,
        'subject': payload.subject ?? payload.title,
        'url': payload.url,
      });
      return success ?? true;
    } on PlatformException catch (e) {
      debugPrint('[AppShareService] PlatformException: ${e.message}');
      if (context.mounted) {
        await _copyToClipboardFallback(context, formattedText);
      }
      return false;
    } catch (e) {
      debugPrint('[AppShareService] Share error: $e');
      if (context.mounted) {
        await _copyToClipboardFallback(context, formattedText);
      }
      return false;
    }
  }

  static Future<void> _copyToClipboardFallback(
    BuildContext context,
    String text,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      debugPrint('[AppShareService] Clipboard fallback error: $e');
    }
    if (context.mounted) {
      AppSnackbar.showInfo(
        context,
        message: 'Link copied to clipboard.',
      );
    }
  }

  // ── Direct Convenience Helpers ──────────────────────────────────────────────

  /// Shares a feed post using the native Android Sharesheet.
  static Future<bool> sharePost(BuildContext context, PostEntity post) =>
      share(context, buildPostPayload(post));

  /// Shares a marketplace listing using the native Android Sharesheet.
  static Future<bool> shareMarketplace(
    BuildContext context,
    MarketplaceListingEntity listing,
  ) => share(context, buildMarketplacePayload(listing));

  /// Shares an event using the native Android Sharesheet.
  static Future<bool> shareEvent(BuildContext context, EventEntity event) =>
      share(context, buildEventPayload(event));

  /// Shares a local business using the native Android Sharesheet.
  static Future<bool> shareBusiness(
    BuildContext context,
    BusinessEntity business,
  ) => share(context, buildBusinessPayload(business));

  /// Shares a local service using the native Android Sharesheet.
  static Future<bool> shareService(
    BuildContext context,
    ServiceListingEntity service,
  ) => share(context, buildServicePayload(service));

  /// Shares a community using the native Android Sharesheet.
  static Future<bool> shareCommunity(
    BuildContext context,
    CommunityEntity community,
  ) => share(context, buildCommunityPayload(community));

  // ── In-App Messaging Sharing ("Send in Aaspaas") ─────────────────────────────

  /// Opens an in-app bottom sheet enabling the user to choose an existing
  /// Aaspaas conversation and send the shared content into that chat.
  static Future<void> showSendInAaspaasSheet(
    BuildContext context,
    SharePayload payload,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (ctx, ref, _) {
            final state = ref.watch(conversationsControllerProvider);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkOutlineVariant
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Send in Aaspaas',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a neighbor or group conversation:',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.slate500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      thickness: 0.6,
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(height: 8),

                    if (state.isLoading && state.conversations.isEmpty) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ] else if (state.conversations.isEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: AppEmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No active conversations',
                          description:
                              'Start a conversation with a neighbor first.',
                        ),
                      ),
                    ] else ...[
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(sheetContext).size.height * 0.4,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: state.conversations.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (ctx, index) {
                            final conv = state.conversations[index];
                            final name = conv.participant.displayName;
                            final avatarUrl = conv.participant.avatarUrl;
                            final lastMsg = conv.lastMessage?.content ?? 'Tap to share';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: AppAvatar(
                                name: name,
                                imageUrl: avatarUrl,
                                size: AppAvatarSize.s32,
                              ),
                              title: Text(
                                name,
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                lastMsg,
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.slate400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.slate400,
                              ),
                              onTap: () async {
                                Navigator.of(sheetContext).pop();
                                try {
                                  await ref
                                      .read(
                                        conversationControllerProvider(conv.id)
                                            .notifier,
                                      )
                                      .sendMessage(payload.formattedText);

                                  if (context.mounted) {
                                    AppSnackbar.showSuccess(
                                      context,
                                      message: 'Shared to $name in Aaspaas.',
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    AppSnackbar.showError(
                                      context,
                                      message: 'Unable to send message to $name.',
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

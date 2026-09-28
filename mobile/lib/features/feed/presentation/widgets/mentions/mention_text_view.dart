import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aaspaas/core/theme/app_colors.dart';
import 'package:aaspaas/core/theme/app_typography.dart';
import 'package:aaspaas/features/feed/domain/entities/post_entity.dart';

/// Renders post content text with interactive, styled @mentions that navigate to the user's public profile.
class MentionTextView extends StatefulWidget {
  const MentionTextView({
    required this.text,
    this.mentions = const [],
    this.style,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final List<PostMention> mentions;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<MentionTextView> createState() => _MentionTextViewState();
}

class _MentionTextViewState extends State<MentionTextView> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _navigateToProfile(String username) {
    final clean = username.trim().replaceAll('@', '').toLowerCase();
    if (clean.isNotEmpty) {
      context.push('/@$clean');
    }
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultStyle = widget.style ??
        AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontSize: 15,
          height: 1.4,
        );

    final mentionStyle = defaultStyle.copyWith(
      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    final text = widget.text;

    if (widget.mentions.isNotEmpty) {
      // 1. Render using explicit structured mentions
      final sortedMentions = List<PostMention>.from(widget.mentions)
        ..sort((a, b) => a.start.compareTo(b.start));

      int cursor = 0;
      for (final mention in sortedMentions) {
        if (mention.start < cursor || mention.start + mention.length > text.length) {
          continue;
        }

        // Add leading unmentioned text
        if (mention.start > cursor) {
          spans.add(
            TextSpan(
              text: text.substring(cursor, mention.start),
              style: defaultStyle,
            ),
          );
        }

        // Add interactive mention span
        final mentionToken =
            text.substring(mention.start, mention.start + mention.length);
        final targetUsername =
            mention.username ?? mentionToken.replaceFirst('@', '');

        final recognizer = TapGestureRecognizer()
          ..onTap = () => _navigateToProfile(targetUsername);
        _recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: mentionToken,
            style: mentionStyle,
            recognizer: recognizer,
          ),
        );

        cursor = mention.start + mention.length;
      }

      // Add remaining trailing text
      if (cursor < text.length) {
        spans.add(
          TextSpan(
            text: text.substring(cursor),
            style: defaultStyle,
          ),
        );
      }
    } else {
      // 2. Fallback heuristic for posts without structured mentions: regex match @username
      final mentionRegex = RegExp(r'@([a-zA-Z0-9_]{3,30})');
      int cursor = 0;

      for (final match in mentionRegex.allMatches(text)) {
        if (match.start > cursor) {
          spans.add(
            TextSpan(
              text: text.substring(cursor, match.start),
              style: defaultStyle,
            ),
          );
        }

        final mentionToken = match.group(0)!;
        final username = match.group(1)!;

        final recognizer = TapGestureRecognizer()
          ..onTap = () => _navigateToProfile(username);
        _recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: mentionToken,
            style: mentionStyle,
            recognizer: recognizer,
          ),
        );

        cursor = match.end;
      }

      if (cursor < text.length) {
        spans.add(
          TextSpan(
            text: text.substring(cursor),
            style: defaultStyle,
          ),
        );
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}

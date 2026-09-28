import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aaspaas/features/auth/data/repositories/auth_repository.dart';
import 'package:aaspaas/features/feed/domain/entities/post_entity.dart';
import 'mention_token_parser.dart';

/// Autocomplete state for mention search.
enum MentionState {
  hidden,
  loading,
  hasSuggestions,
  empty,
  error,
}

/// Controller managing @mention token detection, debounced API search,
/// and tracking of structured mentions throughout the drafting lifecycle.
class MentionAutocompleteController extends ChangeNotifier {
  MentionAutocompleteController({
    required this.searchUsers,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  final Future<List<UserSearchResult>> Function(String query) searchUsers;
  final Duration debounceDuration;

  Timer? _debounceTimer;
  int _searchSequence = 0;

  MentionState _state = MentionState.hidden;
  MentionState get state => _state;

  List<UserSearchResult> _suggestions = const [];
  List<UserSearchResult> get suggestions => _suggestions;

  MentionToken? _activeToken;
  MentionToken? get activeToken => _activeToken;

  /// Internal tracking of selected structured mentions.
  final List<PostMention> _selectedMentions = [];
  List<PostMention> get selectedMentions => List.unmodifiable(_selectedMentions);

  /// Called when the text or cursor position in the composer changes.
  void onTextChanged({
    required String text,
    required TextSelection selection,
  }) {
    // 1. Maintain alignment of existing structured mentions
    _realignStructuredMentions(text);

    // 2. Check if cursor is currently within an active @mention trigger
    if (!selection.isValid || !selection.isCollapsed) {
      _dismissSuggestions();
      return;
    }

    final token = MentionTokenParser.findMentionToken(text, selection.baseOffset);
    if (token == null) {
      _dismissSuggestions();
      return;
    }

    _activeToken = token;
    _scheduleSearch(token.query);
  }

  void _scheduleSearch(String query) {
    _debounceTimer?.cancel();

    _state = MentionState.loading;
    notifyListeners();

    final currentSeq = ++_searchSequence;
    _debounceTimer = Timer(debounceDuration, () async {
      try {
        final results = await searchUsers(query);
        // Stale response protection: ignore if a newer search was initiated
        if (_searchSequence != currentSeq) return;

        // Filter out users who do not have a public username
        final withUsername = results
            .where((u) => u.username != null && u.username!.trim().isNotEmpty)
            .take(8)
            .toList();

        if (withUsername.isEmpty) {
          _suggestions = const [];
          _state = MentionState.empty;
        } else {
          _suggestions = withUsername;
          _state = MentionState.hasSuggestions;
        }
        notifyListeners();
      } catch (e) {
        if (_searchSequence != currentSeq) return;
        _suggestions = const [];
        _state = MentionState.error;
        notifyListeners();
      }
    });
  }

  /// Replaces the active @query token with @username and returns updated TextEditingValue.
  TextEditingValue applyMention({
    required UserSearchResult user,
    required TextEditingValue currentValue,
  }) {
    final token = _activeToken;
    final username = user.username?.trim();
    if (token == null || username == null || username.isEmpty) {
      _dismissSuggestions();
      return currentValue;
    }

    final text = currentValue.text;
    final start = token.startIndex;
    final end = token.endIndex;

    // Build replacement: if text already has a space immediately after end, do not duplicate it
    final hasTrailingSpace = end < text.length && text[end] == ' ';
    final replacement = hasTrailingSpace ? '@$username' : '@$username ';
    final newText = text.replaceRange(start, end, replacement);
    final newCursorPosition =
        start + replacement.length + (hasTrailingSpace ? 1 : 0);

    // Record structured mention
    final mention = PostMention(
      userId: user.id,
      start: start,
      length: 1 + username.length, // '@username' length
      username: username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
    );

    // Remove any previously recorded mention that overlapped this range
    _selectedMentions.removeWhere(
      (m) => (m.start >= start && m.start < end) || (m.start == start),
    );
    _selectedMentions.add(mention);

    _dismissSuggestions();

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  /// Validates and realigns existing structured mentions against current text.
  /// If a mention token was deleted or partially modified (e.g. backspaced), it is dropped.
  void _realignStructuredMentions(String text) {
    if (_selectedMentions.isEmpty) return;

    final retained = <PostMention>[];
    for (final mention in _selectedMentions) {
      final tokenText = '@${mention.username}';
      final expectedLength = tokenText.length;

      // Check if it is still at its recorded position
      if (mention.start >= 0 &&
          mention.start + expectedLength <= text.length &&
          text.substring(mention.start, mention.start + expectedLength).toLowerCase() ==
              tokenText.toLowerCase()) {
        retained.add(
          PostMention(
            userId: mention.userId,
            start: mention.start,
            length: expectedLength,
            username: mention.username,
            displayName: mention.displayName,
            avatarUrl: mention.avatarUrl,
          ),
        );
        continue;
      }

      // Check if it was shifted by an insertion or deletion earlier in the text
      int searchFrom = 0;
      bool found = false;
      while (searchFrom < text.length) {
        final idx = text.toLowerCase().indexOf(tokenText.toLowerCase(), searchFrom);
        if (idx == -1) break;

        // Verify word boundaries
        final isPrecededByBoundary = idx == 0 ||
            RegExp(r'[\s\(\[\{"\x27<]').hasMatch(text[idx - 1]);
        final afterIdx = idx + expectedLength;
        final isFollowedByBoundary = afterIdx >= text.length ||
            !RegExp(r'[a-zA-Z0-9_]').hasMatch(text[afterIdx]);

        if (isPrecededByBoundary && isFollowedByBoundary) {
          retained.add(
            PostMention(
              userId: mention.userId,
              start: idx,
              length: expectedLength,
              username: mention.username,
              displayName: mention.displayName,
              avatarUrl: mention.avatarUrl,
            ),
          );
          found = true;
          break;
        }
        searchFrom = idx + 1;
      }

      // If not found in text, the mention was deleted and is dropped
      if (!found) {
        continue;
      }
    }

    _selectedMentions
      ..clear()
      ..addAll(retained);
  }

  /// Returns sorted, validated structured mentions ready for API post creation.
  List<PostMention> getStructuredMentions(String finalContent) {
    _realignStructuredMentions(finalContent);
    // Sort by start offset ascending
    final sorted = List<PostMention>.from(_selectedMentions)
      ..sort((a, b) => a.start.compareTo(b.start));

    // Ensure non-overlapping ranges
    final result = <PostMention>[];
    int lastEnd = 0;
    for (final m in sorted) {
      if (m.start >= lastEnd && m.start + m.length <= finalContent.length) {
        result.add(m);
        lastEnd = m.start + m.length;
      }
    }
    return result;
  }

  void _dismissSuggestions() {
    _debounceTimer?.cancel();
    if (_state != MentionState.hidden) {
      _state = MentionState.hidden;
      _suggestions = const [];
      _activeToken = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

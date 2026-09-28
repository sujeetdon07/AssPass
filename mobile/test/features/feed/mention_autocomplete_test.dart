import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/features/auth/data/repositories/auth_repository.dart';
import 'package:aaspaas/features/feed/domain/entities/post_entity.dart';
import 'package:aaspaas/features/feed/presentation/widgets/mentions/mention_autocomplete_controller.dart';
import 'package:aaspaas/features/feed/presentation/widgets/mentions/mention_suggestion_panel.dart';
import 'package:aaspaas/features/feed/presentation/widgets/mentions/mention_text_view.dart';
import 'package:aaspaas/features/feed/presentation/widgets/mentions/mention_token_parser.dart';

void main() {
  group('MentionTokenParser Unit Tests', () {
    test('detects "@" trigger at start of string with empty query', () {
      final token = MentionTokenParser.findMentionToken('@', 1);
      expect(token, isNotNull);
      expect(token!.startIndex, equals(0));
      expect(token.endIndex, equals(1));
      expect(token.query, equals(''));
    });

    test('detects "@su" trigger with query "su"', () {
      final token = MentionTokenParser.findMentionToken('@su', 3);
      expect(token, isNotNull);
      expect(token!.startIndex, equals(0));
      expect(token.endIndex, equals(3));
      expect(token.query, equals('su'));
    });

    test('detects mention trigger in middle of text', () {
      const text = 'Hello @su please check';
      // Cursor is at index 9 (right after 'u')
      final token = MentionTokenParser.findMentionToken(text, 9);
      expect(token, isNotNull);
      expect(token!.startIndex, equals(6));
      expect(token.endIndex, equals(9));
      expect(token.query, equals('su'));
    });

    test('does NOT trigger inside an email address', () {
      const text = 'email@test.com';
      // Cursor after '@'
      expect(MentionTokenParser.findMentionToken(text, 6), isNull);
      // Cursor inside 'test'
      expect(MentionTokenParser.findMentionToken(text, 8), isNull);
    });

    test('triggers when preceded by opening parentheses or punctuation', () {
      const text = 'Hey (@suj';
      final token = MentionTokenParser.findMentionToken(text, 9);
      expect(token, isNotNull);
      expect(token!.startIndex, equals(5));
      expect(token.query, equals('suj'));
    });

    test('excludes punctuation following the token', () {
      const text = 'Hey @sujeet!';
      // Cursor at index 11 (after 't', before '!')
      final token = MentionTokenParser.findMentionToken(text, 11);
      expect(token, isNotNull);
      expect(token!.startIndex, equals(4));
      expect(token.endIndex, equals(11));
      expect(token.query, equals('sujeet'));
    });
  });

  group('MentionAutocompleteController Unit Tests', () {
    const mockUser1 = UserSearchResult(
      id: 'usr-1',
      username: 'sujeet',
      displayName: 'Sujeet Kumar',
      avatarUrl: null,
      locality: 'Indiranagar',
      city: 'Bengaluru',
    );

    const mockUser2 = UserSearchResult(
      id: 'usr-2',
      username: 'suman',
      displayName: 'Suman Sharma',
      avatarUrl: null,
      locality: 'Koramangala',
      city: 'Bengaluru',
    );

    test('debounces search calls and populates suggestions', () async {
      int searchCallCount = 0;
      final controller = MentionAutocompleteController(
        debounceDuration: const Duration(milliseconds: 50),
        searchUsers: (query) async {
          searchCallCount++;
          return [mockUser1, mockUser2];
        },
      );

      controller.onTextChanged(
        text: 'Hello @su',
        selection: const TextSelection.collapsed(offset: 9),
      );

      expect(controller.state, equals(MentionState.loading));
      expect(searchCallCount, equals(0));

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(searchCallCount, equals(1));
      expect(controller.state, equals(MentionState.hasSuggestions));
      expect(controller.suggestions.length, equals(2));

      controller.dispose();
    });

    test('protects against stale search responses', () async {
      final controller = MentionAutocompleteController(
        debounceDuration: const Duration(milliseconds: 20),
        searchUsers: (query) async {
          if (query == 's') {
            // Simulate slow response for first query
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return [mockUser2];
          } else {
            // Fast response for second query
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return [mockUser1];
          }
        },
      );

      // First query '@s'
      controller.onTextChanged(
        text: '@s',
        selection: const TextSelection.collapsed(offset: 2),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Second query '@su'
      controller.onTextChanged(
        text: '@su',
        selection: const TextSelection.collapsed(offset: 3),
      );

      // Wait for both to complete
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Result should be mockUser1 from '@su', not stale mockUser2 from '@s'
      expect(controller.suggestions.first.username, equals('sujeet'));

      controller.dispose();
    });

    test('handles empty search results gracefully', () async {
      final controller = MentionAutocompleteController(
        debounceDuration: const Duration(milliseconds: 20),
        searchUsers: (query) async => [],
      );

      controller.onTextChanged(
        text: '@nobody',
        selection: const TextSelection.collapsed(offset: 7),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.state, equals(MentionState.empty));
      expect(controller.suggestions, isEmpty);

      controller.dispose();
    });

    test('handles search errors gracefully', () async {
      final controller = MentionAutocompleteController(
        debounceDuration: const Duration(milliseconds: 20),
        searchUsers: (query) async => throw Exception('Network error'),
      );

      controller.onTextChanged(
        text: '@err',
        selection: const TextSelection.collapsed(offset: 4),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.state, equals(MentionState.error));
      expect(controller.suggestions, isEmpty);

      controller.dispose();
    });

    test('applyMention replaces token with @username and trailing space', () async {
      final controller = MentionAutocompleteController(
        debounceDuration: const Duration(milliseconds: 20),
        searchUsers: (query) async => [mockUser1],
      );

      controller.onTextChanged(
        text: 'Hello @su please check',
        selection: const TextSelection.collapsed(offset: 9),
      );

      final newValue = controller.applyMention(
        user: mockUser1,
        currentValue: const TextEditingValue(
          text: 'Hello @su please check',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );

      // Expect 'Hello @sujeet please check'
      expect(newValue.text, equals('Hello @sujeet please check'));
      // Cursor should be at index 14 (right after '@sujeet ')
      expect(newValue.selection.baseOffset, equals(14));

      final mentions = controller.getStructuredMentions(newValue.text);
      expect(mentions.length, equals(1));
      expect(mentions.first.userId, equals(mockUser1.id));
      expect(mentions.first.start, equals(6));
      expect(mentions.first.length, equals(7)); // '@sujeet' has length 7

      controller.dispose();
    });

    test('drops structured mention when user deletes or edits the token text', () {
      final controller = MentionAutocompleteController(
        searchUsers: (query) async => [mockUser1],
      );

      controller.onTextChanged(
        text: 'Hey @su',
        selection: const TextSelection.collapsed(offset: 7),
      );

      controller.applyMention(
        user: mockUser1,
        currentValue: const TextEditingValue(
          text: 'Hey @su',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );

      // Text is now 'Hey @sujeet '
      expect(controller.selectedMentions.length, equals(1));

      // User backspaces the 't' so it becomes 'Hey @sujee '
      controller.onTextChanged(
        text: 'Hey @sujee ',
        selection: const TextSelection.collapsed(offset: 10),
      );

      // The mention token no longer matches '@sujeet', so it must be dropped
      final mentions = controller.getStructuredMentions('Hey @sujee ');
      expect(mentions, isEmpty);

      controller.dispose();
    });

    test('realigns mention start offset when text is inserted before the mention', () {
      final controller = MentionAutocompleteController(
        searchUsers: (query) async => [mockUser1],
      );

      controller.onTextChanged(
        text: '@su',
        selection: const TextSelection.collapsed(offset: 3),
      );

      controller.applyMention(
        user: mockUser1,
        currentValue: const TextEditingValue(
          text: '@su',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );

      // Originally at start 0: '@sujeet '
      expect(controller.selectedMentions.first.start, equals(0));

      // User adds 'Hello ' in front: 'Hello @sujeet '
      const updatedText = 'Hello @sujeet ';
      controller.onTextChanged(
        text: updatedText,
        selection: const TextSelection.collapsed(offset: updatedText.length),
      );

      final mentions = controller.getStructuredMentions(updatedText);
      expect(mentions.length, equals(1));
      expect(mentions.first.start, equals(6));
      expect(mentions.first.length, equals(7));

      controller.dispose();
    });
  });

  group('Mention Suggestion UI Widget Tests', () {
    const mockUser = UserSearchResult(
      id: 'usr-sujeet',
      username: 'sujeet',
      displayName: 'Sujeet Kumar',
      avatarUrl: null,
      locality: 'Indiranagar',
      city: 'Bengaluru',
    );

    testWidgets('renders suggestion panel and triggers onSelect callback', (tester) async {
      final controller = MentionAutocompleteController(
        debounceDuration: const Duration(milliseconds: 10),
        searchUsers: (query) async => [mockUser],
      );

      UserSearchResult? selectedUser;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MentionSuggestionPanel(
              controller: controller,
              onSelect: (user) => selectedUser = user,
            ),
          ),
        ),
      );

      // Initially hidden
      expect(find.text('Sujeet Kumar'), findsNothing);

      // Trigger search
      controller.onTextChanged(
        text: '@su',
        selection: const TextSelection.collapsed(offset: 3),
      );

      await tester.pump(); // Start search
      await tester.pump(const Duration(milliseconds: 50)); // Finish debounce & search

      expect(find.text('Sujeet Kumar'), findsOneWidget);
      expect(find.text('@sujeet'), findsOneWidget);

      // Tap suggestion row
      await tester.tap(find.text('Sujeet Kumar'));
      await tester.pump();

      expect(selectedUser, isNotNull);
      expect(selectedUser!.username, equals('sujeet'));

      controller.dispose();
    });
  });

  group('MentionTextView Interactive Post Rendering Tests', () {
    testWidgets('renders plain text alongside highlighted interactive @mention', (tester) async {
      const mention = PostMention(
        userId: 'usr-1',
        start: 4,
        length: 7,
        username: 'sujeet',
        displayName: 'Sujeet Kumar',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MentionTextView(
              text: 'Hey @sujeet, welcome to Aaspaas!',
              mentions: [mention],
            ),
          ),
        ),
      );

      expect(find.text('Hey @sujeet, welcome to Aaspaas!'), findsOneWidget);
    });
  });
}

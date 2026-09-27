import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/messaging/domain/entities/conversation_entity.dart';
import 'package:aaspaas/features/messaging/domain/entities/message_entity.dart';
import 'package:aaspaas/features/messaging/presentation/widgets/conversation_list_tile.dart';
import 'package:aaspaas/features/messaging/presentation/widgets/message_bubble.dart';
import 'package:aaspaas/features/messaging/presentation/widgets/message_composer.dart';
import 'package:aaspaas/features/messaging/presentation/widgets/typing_indicator_widget.dart';
import 'package:aaspaas/features/messaging/l10n/messaging_localizations.dart';

void main() {
  group('Messaging Localization Tests', () {
    test('Returns correct English and Hindi translations', () {
      expect(MessagingStrings.get('messages', 'en'), 'Messages');
      expect(MessagingStrings.get('messages', 'hi'), 'संदेश');
      expect(MessagingStrings.get('typeMessage', 'en'), 'Type a message...');
      expect(MessagingStrings.get('typeMessage', 'hi'), 'संदेश लिखें...');
      expect(MessagingStrings.get('online', 'en'), 'Online');
      expect(MessagingStrings.get('online', 'hi'), 'ऑनलाइन');
    });
  });

  group('MessageBubble Widget Tests', () {
    testWidgets('renders my sent message with time and checkmark',
        (tester) async {
      final message = MessageEntity(
        id: 'msg-1',
        conversationId: 'conv-1',
        senderId: 'me-1',
        clientMessageId: 'cli-1',
        content: 'Namaste neighbor!',
        messageType: 'TEXT',
        isMe: true,
        createdAt: DateTime(2026, 9, 24, 10, 30),
        status: MessageStatus.sent,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message),
          ),
        ),
      );

      expect(find.text('Namaste neighbor!'), findsOneWidget);
      expect(find.text('10:30 AM'), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
    });

    testWidgets('renders read receipt with double checkmark when readAt is set',
        (tester) async {
      final message = MessageEntity(
        id: 'msg-2',
        conversationId: 'conv-1',
        senderId: 'me-1',
        clientMessageId: 'cli-2',
        content: 'Is this still available?',
        messageType: 'TEXT',
        isMe: true,
        createdAt: DateTime(2026, 9, 24, 14, 15),
        status: MessageStatus.sent,
        readAt: DateTime(2026, 9, 24, 14, 16),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message),
          ),
        ),
      );

      expect(find.text('Is this still available?'), findsOneWidget);
      expect(find.text('2:15 PM'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    });

    testWidgets('renders failed message with retry icon and triggers callback',
        (tester) async {
      var retried = false;
      final message = MessageEntity(
        id: 'msg-3',
        conversationId: 'conv-1',
        senderId: 'me-1',
        clientMessageId: 'cli-3',
        content: 'Failed to deliver',
        messageType: 'TEXT',
        isMe: true,
        createdAt: DateTime(2026, 9, 24, 15, 0),
        status: MessageStatus.failed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to deliver'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsWidgets);

      await tester.tap(find.byIcon(Icons.error_outline_rounded).first);
      expect(retried, isTrue);
    });

    testWidgets('renders recipient message aligned left with no status icon',
        (tester) async {
      final message = MessageEntity(
        id: 'msg-4',
        conversationId: 'conv-1',
        senderId: 'other-1',
        clientMessageId: 'cli-4',
        content: 'Yes, it is available for pickup!',
        messageType: 'TEXT',
        isMe: false,
        createdAt: DateTime(2026, 9, 24, 16, 20),
        status: MessageStatus.sent,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message),
          ),
        ),
      );

      expect(find.text('Yes, it is available for pickup!'), findsOneWidget);
      expect(find.text('4:20 PM'), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsNothing);
    });
  });

  group('MessageComposer Widget Tests', () {
    testWidgets('send button is disabled when text field is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageComposer(onSend: (_) {}),
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('typing invokes onTyping and enables send button',
        (tester) async {
      String? sentText;
      String? lastTyping;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageComposer(
              onSend: (text) => sentText = text,
              onTyping: (text) => lastTyping = text,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello Aaspaas!');
      await tester.pump();

      expect(lastTyping, 'Hello Aaspaas!');

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNotNull);

      await tester.tap(find.byType(IconButton));
      expect(sentText, 'Hello Aaspaas!');
      expect(find.text('Hello Aaspaas!'), findsNothing);
    });
  });

  group('ConversationListTile Widget Tests', () {
    testWidgets(
        'renders participant info, last message preview, and unread badge',
        (tester) async {
      var tapped = false;
      final now = DateTime(2026, 9, 24, 17, 0);
      final conversation = ConversationEntity(
        id: 'conv-123',
        participant: const ConversationParticipantProfile(
          id: 'user-b',
          displayName: 'Ramesh Sharma',
          avatarUrl: null,
          locality: 'Indiranagar',
          city: 'Bengaluru',
        ),
        lastMessage: MessageEntity(
          id: 'last-msg-1',
          conversationId: 'conv-123',
          senderId: 'user-b',
          clientMessageId: 'cli-last',
          content: 'I will see you at 5 PM',
          messageType: 'TEXT',
          createdAt: now,
          status: MessageStatus.sent,
        ),
        lastMessageAt: now,
        unreadCount: 3,
        isOnline: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationListTile(
              conversation: conversation,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Ramesh Sharma'), findsOneWidget);
      expect(find.text('I will see you at 5 PM'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byType(ConversationListTile));
      expect(tapped, isTrue);
    });
  });

  group('TypingIndicatorWidget Tests', () {
    testWidgets('renders typing text and animates dots without crashing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicatorWidget(),
          ),
        ),
      );

      expect(find.text('Typing…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TypingIndicatorWidget), findsOneWidget);
    });
  });
}

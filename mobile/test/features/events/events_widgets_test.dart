import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/events/domain/entities/event_category.dart';
import 'package:aaspaas/features/events/domain/entities/event_entity.dart';
import 'package:aaspaas/features/events/domain/entities/event_rsvp_status.dart';
import 'package:aaspaas/features/events/presentation/widgets/event_card.dart';
import 'package:aaspaas/features/events/presentation/widgets/event_filter_sheet.dart';
import 'package:aaspaas/core/theme/app_theme.dart';

EventEntity createWidgetTestEvent({
  String id = 'evt-widget-1',
  String title = 'Indiranagar Community Cleanliness Drive',
  EventCategory category = EventCategory.volunteering,
  EventRsvpStatus? userRsvpStatus,
  int participantCount = 12,
  bool isOrganizer = false,
  bool isCancelled = false,
}) {
  final now = DateTime.now();
  return EventEntity(
    id: id,
    creatorId: 'user-organizer-7',
    creator: const EventOrganizerEntity(
      id: 'user-organizer-7',
      displayName: 'Rohan Sharma',
    ),
    title: title,
    description: 'Help clean up the neighborhood park this Sunday morning.',
    category: category,
    status: isCancelled ? 'cancelled' : 'active',
    startAt: now.add(const Duration(days: 1, hours: 2)),
    endAt: now.add(const Duration(days: 1, hours: 4)),
    timezone: 'Asia/Kolkata',
    venue: 'BDA Complex Park',
    address: '100 Feet Rd, Indiranagar',
    locality: 'Indiranagar',
    city: 'Bengaluru',
    participantCount: participantCount,
    userRsvpStatus: userRsvpStatus,
    isOrganizer: isOrganizer,
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now.subtract(const Duration(days: 2)),
  );
}

void main() {
  group('EventCard Widget', () {
    testWidgets('renders event title, category, venue, and attendee count',
        (tester) async {
      final event = createWidgetTestEvent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(
              event: event,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Indiranagar Community Cleanliness Drive'), findsOneWidget);
      expect(find.text('Volunteering & Civic'), findsOneWidget);
      expect(find.textContaining('BDA Complex Park'), findsOneWidget);
      expect(find.textContaining('12 going'), findsOneWidget);
    });

    testWidgets('displays Going badge when current user has RSVPed',
        (tester) async {
      final event = createWidgetTestEvent(
        userRsvpStatus: EventRsvpStatus.going,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(
              event: event,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Going'), findsOneWidget);
    });

    testWidgets('displays CANCELLED badge when event is cancelled',
        (tester) async {
      final event = createWidgetTestEvent(isCancelled: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(
              event: event,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('CANCELLED'), findsOneWidget);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      final event = createWidgetTestEvent();
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(
              event: event,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(EventCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('EventFilterSheet Widget', () {
    testWidgets('renders filter title and category choices', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventFilterSheet(
              selectedTimeframe: 'upcoming',
              selectedCategory: null,
              onApply: (timeframe, category) {},
            ),
          ),
        ),
      );

      expect(find.text('Filter Events'), findsOneWidget);
      expect(find.text('Timeframe'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Social & Meetups'), findsOneWidget);
      expect(find.text('Sports & Fitness'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);
    });
  });

  group('Events Layout Regression Tests (Physical Device 360dp)', () {
    testWidgets(
        'EventCard renders without RenderFlex overflow on narrow 360dp screen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0; // 360dp logical width
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final event = createWidgetTestEvent(
        title:
            'Indiranagar Weekend Long Distance 10K Community Marathon and Cleanliness Drive',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EventCard(
              event: event,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(EventCard), findsOneWidget);
    });

    testWidgets(
        'OutlinedButton and FilledButton in Row do not throw BoxConstraints infinite width exception with AppTheme',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0; // 360dp logical width
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.calendar_today_outlined, size: 16),
                          label: const Text('Sun, Sep 27, 2026'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.access_time, size: 16),
                          label: const Text('10:00 AM'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Going'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.star_border, size: 18),
                          label: const Text('Interested'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(OutlinedButton), findsNWidgets(3));
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}


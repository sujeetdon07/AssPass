import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaspaas/features/events/application/events_controller.dart';
import 'package:aaspaas/features/events/data/models/events_page_model.dart';
import 'package:aaspaas/features/events/data/repositories/events_repository.dart';
import 'package:aaspaas/features/events/domain/entities/event_category.dart';
import 'package:aaspaas/features/events/domain/entities/event_entity.dart';
import 'package:aaspaas/features/events/domain/entities/event_participant_entity.dart';
import 'package:aaspaas/features/events/domain/entities/event_rsvp_status.dart';

EventEntity createTestEvent({
  String id = 'evt-1',
  String title = 'Indiranagar Book Club',
  EventCategory category = EventCategory.workshop,
  DateTime? startAt,
  DateTime? endAt,
  int participantCount = 5,
  EventRsvpStatus? userRsvpStatus,
  bool isOrganizer = false,
  String status = 'active',
}) {
  final now = DateTime.now();
  return EventEntity(
    id: id,
    creatorId: 'user-organizer-1',
    creator: const EventOrganizerEntity(
      id: 'user-organizer-1',
      displayName: 'Kavita Menon',
    ),
    title: title,
    description: 'A cozy reading and discussion club for local bibliophiles.',
    category: category,
    status: status,
    startAt: startAt ?? now.add(const Duration(days: 2)),
    endAt: endAt ?? now.add(const Duration(days: 2, hours: 2)),
    timezone: 'Asia/Kolkata',
    venue: 'Corner Coffee, 12th Main',
    address: 'Indiranagar, Bengaluru',
    locality: 'Indiranagar',
    city: 'Bengaluru',
    participantCount: participantCount,
    userRsvpStatus: userRsvpStatus,
    isOrganizer: isOrganizer,
    createdAt: now.subtract(const Duration(days: 1)),
    updatedAt: now.subtract(const Duration(days: 1)),
  );
}

class _FakeEventsRepository extends Fake implements EventsRepository {
  List<EventEntity> eventsToReturn = [];
  bool shouldThrow = false;
  int rsvpCallCount = 0;
  int cancelRsvpCallCount = 0;

  @override
  Future<EventsPageModel> getEvents({
    String? cursor,
    int limit = 20,
    String? category,
    String? communityId,
    String? locality,
    String? city,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String timeframe = 'upcoming',
    String? search,
  }) async {
    if (shouldThrow) throw Exception('Network timeout');
    return EventsPageModel(
      events: eventsToReturn,
      hasMore: eventsToReturn.length >= limit,
      nextCursor: eventsToReturn.isNotEmpty ? 'cursor-next' : null,
    );
  }

  @override
  Future<Map<String, dynamic>> rsvpEvent(
    String id, {
    EventRsvpStatus status = EventRsvpStatus.going,
  }) async {
    rsvpCallCount++;
    if (shouldThrow) throw Exception('RSVP failed');
    final match = eventsToReturn.firstWhere((e) => e.id == id);
    final count = status == EventRsvpStatus.going ? match.participantCount + 1 : match.participantCount;
    return {'status': status.value, 'participantCount': count};
  }

  @override
  Future<Map<String, dynamic>> cancelRsvp(String id) async {
    cancelRsvpCallCount++;
    if (shouldThrow) throw Exception('Cancel RSVP failed');
    final match = eventsToReturn.firstWhere((e) => e.id == id);
    final count = match.participantCount > 0 ? match.participantCount - 1 : 0;
    return {'status': null, 'participantCount': count};
  }

  @override
  Future<EventEntity> getEventById(String id) async {
    return eventsToReturn.firstWhere((e) => e.id == id);
  }

  @override
  Future<List<EventParticipantEntity>> getParticipants(
    String id, {
    String? cursor,
    int limit = 20,
  }) async {
    return [];
  }
}

void main() {
  late _FakeEventsRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = _FakeEventsRepository();
    container = ProviderContainer(
      overrides: [
        eventsRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('EventsController', () {
    test('initial state loads events successfully', () async {
      final sample = createTestEvent();
      fakeRepo.eventsToReturn = [sample];

      final notifier = container.read(eventsControllerProvider.notifier);
      await notifier.loadEvents(isRefresh: true);

      final state = container.read(eventsControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.events.length, equals(1));
      expect(state.events.first.title, equals('Indiranagar Book Club'));
      expect(state.errorMessage, isNull);
    });

    test('handles error state properly when repo throws', () async {
      fakeRepo.shouldThrow = true;

      final notifier = container.read(eventsControllerProvider.notifier);
      await notifier.loadEvents(isRefresh: true);

      final state = container.read(eventsControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.events, isEmpty);
      expect(state.errorMessage, isNotNull);
    });

    test('filtering by category updates state and reloads', () async {
      fakeRepo.eventsToReturn = [
        createTestEvent(id: 'evt-2', title: '5K Run', category: EventCategory.sports),
      ];

      final notifier = container.read(eventsControllerProvider.notifier);
      notifier.setCategory(EventCategory.sports);

      expect(container.read(eventsControllerProvider).selectedCategory, equals(EventCategory.sports));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(eventsControllerProvider);
      expect(state.events.length, equals(1));
      expect(state.events.first.category, equals(EventCategory.sports));
    });

    test('filtering by timeframe updates timeframe filter', () async {
      final notifier = container.read(eventsControllerProvider.notifier);
      notifier.setTimeframe('weekend');

      expect(container.read(eventsControllerProvider).selectedTimeframe, equals('weekend'));
    });

    test('RSVP going updates event optimistically in list', () async {
      final initial = createTestEvent(id: 'evt-1', participantCount: 5);
      fakeRepo.eventsToReturn = [initial];

      final notifier = container.read(eventsControllerProvider.notifier);
      await notifier.loadEvents(isRefresh: true);

      await notifier.rsvpEvent('evt-1', EventRsvpStatus.going);
      expect(fakeRepo.rsvpCallCount, equals(1));

      final updated = container.read(eventsControllerProvider).events.first;
      expect(updated.userRsvpStatus, equals(EventRsvpStatus.going));
      expect(updated.participantCount, equals(6));
    });

    test('RSVP failure triggers optimistic rollback', () async {
      final initial = createTestEvent(id: 'evt-1', participantCount: 5);
      fakeRepo.eventsToReturn = [initial];

      final notifier = container.read(eventsControllerProvider.notifier);
      await notifier.loadEvents(isRefresh: true);

      fakeRepo.shouldThrow = true;
      await notifier.rsvpEvent('evt-1', EventRsvpStatus.going);

      final rolledBack = container.read(eventsControllerProvider).events.first;
      expect(rolledBack.userRsvpStatus, isNull);
      expect(rolledBack.participantCount, equals(5));
    });

    test('Cancel RSVP updates event in list', () async {
      final initial = createTestEvent(
        id: 'evt-1',
        participantCount: 6,
        userRsvpStatus: EventRsvpStatus.going,
      );
      fakeRepo.eventsToReturn = [initial];

      final notifier = container.read(eventsControllerProvider.notifier);
      await notifier.loadEvents(isRefresh: true);

      await notifier.cancelRsvp('evt-1');
      expect(fakeRepo.cancelRsvpCallCount, equals(1));

      final updated = container.read(eventsControllerProvider).events.first;
      expect(updated.userRsvpStatus, isNull);
      expect(updated.participantCount, equals(5));
    });

    test('onEventCancelled removes cancelled event from active list', () async {
      final e1 = createTestEvent(id: 'evt-1');
      final e2 = createTestEvent(id: 'evt-2');
      fakeRepo.eventsToReturn = [e1, e2];

      final notifier = container.read(eventsControllerProvider.notifier);
      await notifier.loadEvents(isRefresh: true);
      expect(container.read(eventsControllerProvider).events.length, equals(2));

      notifier.onEventCancelled('evt-1');
      expect(container.read(eventsControllerProvider).events.length, equals(1));
      expect(container.read(eventsControllerProvider).events.first.id, equals('evt-2'));
    });

    test('onEventUpdated replaces existing event in list', () async {
      final e1 = createTestEvent(id: 'evt-1', title: 'Old Title');
      fakeRepo.eventsToReturn = [e1];

      final notifier = container.read(eventsControllerProvider.notifier);
      await notifier.loadEvents(isRefresh: true);

      final updated = e1.copyWith(title: 'Updated Title');
      notifier.onEventUpdated(updated);

      expect(container.read(eventsControllerProvider).events.first.title, equals('Updated Title'));
    });
  });
}

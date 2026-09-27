import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aaspaas/features/events/application/event_detail_controller.dart';
import 'package:aaspaas/features/events/data/models/events_page_model.dart';
import 'package:aaspaas/features/events/data/repositories/events_repository.dart';
import 'package:aaspaas/features/events/domain/entities/event_category.dart';
import 'package:aaspaas/features/events/domain/entities/event_entity.dart';
import 'package:aaspaas/features/events/domain/entities/event_participant_entity.dart';
import 'package:aaspaas/features/events/domain/entities/event_rsvp_status.dart';

EventEntity createDetailTestEvent({
  String id = 'evt-detail-1',
  String title = 'Pottery Workshop',
  bool isOrganizer = false,
  EventRsvpStatus? userRsvpStatus,
  int participantCount = 4,
  String status = 'active',
}) {
  final now = DateTime.now();
  return EventEntity(
    id: id,
    creatorId: 'organizer-42',
    creator: const EventOrganizerEntity(
      id: 'organizer-42',
      displayName: 'Meera Rao',
    ),
    title: title,
    description: 'Learn the basics of wheel pottery with local artist Meera.',
    category: EventCategory.workshop,
    status: status,
    startAt: now.add(const Duration(days: 3)),
    endAt: now.add(const Duration(days: 3, hours: 3)),
    timezone: 'Asia/Kolkata',
    venue: 'Clay Studio 42',
    address: 'Indiranagar 80ft Road',
    locality: 'Indiranagar',
    city: 'Bengaluru',
    participantCount: participantCount,
    userRsvpStatus: userRsvpStatus,
    isOrganizer: isOrganizer,
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now.subtract(const Duration(days: 2)),
  );
}

class _FakeDetailEventsRepository extends Fake implements EventsRepository {
  EventEntity currentEvent;
  List<EventParticipantEntity> participants = [];
  bool shouldThrow = false;
  String? reportedReason;
  String? cancelledReason;

  _FakeDetailEventsRepository(this.currentEvent);

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
    return EventsPageModel(events: [currentEvent], hasMore: false);
  }

  @override
  Future<EventEntity> getEventById(String id) async {
    if (shouldThrow) throw Exception('Fetch failed');
    return currentEvent;
  }

  @override
  Future<List<EventParticipantEntity>> getParticipants(
    String id, {
    String? cursor,
    int limit = 20,
  }) async {
    if (shouldThrow) throw Exception('Participants failed');
    return participants;
  }

  @override
  Future<Map<String, dynamic>> rsvpEvent(
    String id, {
    EventRsvpStatus status = EventRsvpStatus.going,
  }) async {
    if (shouldThrow) throw Exception('RSVP failed');
    currentEvent = currentEvent.copyWith(
      userRsvpStatus: status,
      participantCount: status == EventRsvpStatus.going
          ? currentEvent.participantCount + 1
          : currentEvent.participantCount,
    );
    return {'status': status.value, 'participantCount': currentEvent.participantCount};
  }

  @override
  Future<Map<String, dynamic>> cancelRsvp(String id) async {
    if (shouldThrow) throw Exception('Cancel RSVP failed');
    currentEvent = currentEvent.copyWith(
      userRsvpStatus: null,
      participantCount: currentEvent.userRsvpStatus == EventRsvpStatus.going
          ? currentEvent.participantCount - 1
          : currentEvent.participantCount,
    );
    return {'status': null, 'participantCount': currentEvent.participantCount};
  }

  @override
  Future<EventEntity> cancelEvent(String eventId, {String? reason}) async {
    if (shouldThrow) throw Exception('Cancel event failed');
    cancelledReason = reason;
    currentEvent = currentEvent.copyWith(
      status: 'cancelled',
      cancellationReason: reason,
      cancelledAt: DateTime.now(),
    );
    return currentEvent;
  }

  @override
  Future<void> reportEvent(
    String eventId, {
    required String reason,
    String? details,
  }) async {
    if (shouldThrow) throw Exception('Report failed');
    reportedReason = reason;
  }
}

void main() {
  late _FakeDetailEventsRepository fakeRepo;
  late ProviderContainer container;
  final sampleEvent = createDetailTestEvent();

  setUp(() {
    fakeRepo = _FakeDetailEventsRepository(sampleEvent);
    container = ProviderContainer(
      overrides: [
        eventsRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('EventDetailController', () {
    test('loads event by id and updates state', () async {
      final controller = container.read(eventDetailControllerProvider('evt-detail-1').notifier);
      await controller.loadEvent();

      final state = container.read(eventDetailControllerProvider('evt-detail-1'));
      expect(state.isLoading, isFalse);
      expect(state.event, isNotNull);
      expect(state.event!.title, equals('Pottery Workshop'));
      expect(state.errorMessage, isNull);
    });

    test('handles load error gracefully', () async {
      fakeRepo.shouldThrow = true;
      final controller = container.read(eventDetailControllerProvider('evt-detail-1').notifier);
      await controller.loadEvent();

      final state = container.read(eventDetailControllerProvider('evt-detail-1'));
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNotNull);
    });

    test('rsvp going updates event RSVP state and participant count', () async {
      final controller = container.read(eventDetailControllerProvider('evt-detail-1').notifier);
      await controller.loadEvent();

      final success = await controller.rsvp(EventRsvpStatus.going);
      expect(success, isTrue);

      final state = container.read(eventDetailControllerProvider('evt-detail-1'));
      expect(state.event!.userRsvpStatus, equals(EventRsvpStatus.going));
      expect(state.event!.participantCount, equals(5));
      expect(state.actionMessage, contains('attending'));
    });

    test('cancel RSVP resets RSVP status', () async {
      fakeRepo.currentEvent = createDetailTestEvent(
        userRsvpStatus: EventRsvpStatus.going,
        participantCount: 5,
      );

      final controller = container.read(eventDetailControllerProvider('evt-detail-1').notifier);
      await controller.loadEvent();

      final success = await controller.cancelRsvp();
      expect(success, isTrue);

      final state = container.read(eventDetailControllerProvider('evt-detail-1'));
      expect(state.event!.userRsvpStatus, isNull);
      expect(state.event!.participantCount, equals(4));
    });

    test('cancel event transitions status to cancelled and records reason', () async {
      fakeRepo.currentEvent = createDetailTestEvent(isOrganizer: true);

      final controller = container.read(eventDetailControllerProvider('evt-detail-1').notifier);
      await controller.loadEvent();

      final success = await controller.cancelEvent(reason: 'Instructor sick');
      expect(success, isTrue);
      expect(fakeRepo.cancelledReason, equals('Instructor sick'));

      final state = container.read(eventDetailControllerProvider('evt-detail-1'));
      expect(state.event!.isCancelled, isTrue);
      expect(state.event!.cancellationReason, equals('Instructor sick'));
    });

    test('report event submits to Trust & Safety via repository', () async {
      final controller = container.read(eventDetailControllerProvider('evt-detail-1').notifier);
      await controller.loadEvent();

      final success = await controller.reportEvent('spam', details: 'Promotional fake event');
      expect(success, isTrue);
      expect(fakeRepo.reportedReason, equals('spam'));
    });
  });
}

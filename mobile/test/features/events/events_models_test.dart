import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/events/domain/entities/event_category.dart';
import 'package:aaspaas/features/events/domain/entities/event_rsvp_status.dart';
import 'package:aaspaas/features/events/data/models/event_model.dart';
import 'package:aaspaas/features/events/data/models/event_participant_model.dart';
import 'package:aaspaas/features/events/data/models/events_page_model.dart';

void main() {
  group('EventCategory', () {
    test('parses known categories correctly', () {
      expect(EventCategory.fromString('social'), equals(EventCategory.social));
      expect(EventCategory.fromString('sports'), equals(EventCategory.sports));
      expect(EventCategory.fromString('cultural'), equals(EventCategory.cultural));
      expect(EventCategory.fromString('workshop'), equals(EventCategory.workshop));
      expect(EventCategory.fromString('volunteering'), equals(EventCategory.volunteering));
      expect(EventCategory.fromString('neighborhood'), equals(EventCategory.neighborhood));
      expect(EventCategory.fromString('other'), equals(EventCategory.other));
    });

    test('falls back to other for unknown string', () {
      expect(EventCategory.fromString('nonexistent'), equals(EventCategory.other));
      expect(EventCategory.fromString(null), equals(EventCategory.other));
    });
  });

  group('EventRsvpStatus', () {
    test('parses status correctly', () {
      expect(EventRsvpStatus.fromString('going'), equals(EventRsvpStatus.going));
      expect(EventRsvpStatus.fromString('interested'), equals(EventRsvpStatus.interested));
      expect(EventRsvpStatus.fromString('not_going'), equals(EventRsvpStatus.notGoing));
      expect(EventRsvpStatus.fromString(null), isNull);
    });
  });

  group('EventModel', () {
    final sampleJson = {
      'id': 'evt-100',
      'title': 'Indiranagar Morning Tree Plantation',
      'description': 'Join neighbors to plant 50 native trees around 100ft road.',
      'category': 'volunteering',
      'status': 'active',
      'startAt': '2026-10-01T07:00:00.000Z',
      'endAt': '2026-10-01T10:00:00.000Z',
      'timezone': 'Asia/Kolkata',
      'venue': 'Indiranagar Park, 100ft Rd',
      'address': 'HAL 2nd Stage, Indiranagar',
      'locality': 'Indiranagar',
      'city': 'Bengaluru',
      'latitude': 12.9716,
      'longitude': 77.6412,
      'coverImageUrl': 'https://storage.aaspaas.in/events/tree-plant.jpg',
      'creatorId': 'user-1',
      'creator': {
        'id': 'user-1',
        'displayName': 'Arun Sharma',
      },
      'communityId': 'comm-indiranagar',
      'community': {
        'id': 'comm-indiranagar',
        'name': 'Indiranagar Residents Welfare',
        'slug': 'indiranagar-rw',
        'visibility': 'public',
      },
      'participantCount': 18,
      'userRsvpStatus': 'going',
      'isOrganizer': true,
      'distanceMeters': 450.0,
      'createdAt': '2026-09-25T10:00:00.000Z',
      'updatedAt': '2026-09-25T10:00:00.000Z',
      'cancelledAt': null,
      'cancellationReason': null,
    };

    test('deserializes JSON into entity correctly', () {
      final model = EventModel.fromJson(sampleJson);
      final entity = model.toEntity();

      expect(entity.id, equals('evt-100'));
      expect(entity.title, equals('Indiranagar Morning Tree Plantation'));
      expect(entity.category, equals(EventCategory.volunteering));
      expect(entity.venue, equals('Indiranagar Park, 100ft Rd'));
      expect(entity.locality, equals('Indiranagar'));
      expect(entity.participantCount, equals(18));
      expect(entity.userRsvpStatus, equals(EventRsvpStatus.going));
      expect(entity.isOrganizer, isTrue);
      expect(entity.isGoing, isTrue);
      expect(entity.isInterested, isFalse);
      expect(entity.isCancelled, isFalse);
      expect(entity.distanceMeters, equals(450.0));
      expect(entity.creator?.displayName, equals('Arun Sharma'));
    });
  });

  group('EventsPageModel', () {
    test('deserializes paginated events correctly', () {
      final pageJson = {
        'items': [
          {
            'id': 'evt-1',
            'title': 'Weekend Cricket Match',
            'category': 'sports',
            'startAt': '2026-10-02T08:00:00.000Z',
            'endAt': '2026-10-02T11:00:00.000Z',
            'venue': 'BDA Ground',
            'creatorId': 'u1',
            'createdAt': '2026-09-25T10:00:00.000Z',
            'updatedAt': '2026-09-25T10:00:00.000Z',
          }
        ],
        'total': 1,
        'hasMore': false,
        'nextCursor': null,
      };

      final page = EventsPageModel.fromJson(pageJson);
      expect(page.events.length, equals(1));
      expect(page.events.first.title, equals('Weekend Cricket Match'));
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });
  });

  group('EventParticipantModel', () {
    test('deserializes participant correctly', () {
      final participantJson = {
        'id': 'rsvp-1',
        'userId': 'usr-42',
        'displayName': 'Priya Patel',
        'avatarUrl': 'https://storage.aaspaas.in/avatars/priya.jpg',
        'status': 'going',
        'createdAt': '2026-09-25T12:00:00.000Z',
      };

      final participant = EventParticipantModel.fromJson(participantJson).toEntity();
      expect(participant.id, equals('rsvp-1'));
      expect(participant.userId, equals('usr-42'));
      expect(participant.displayName, equals('Priya Patel'));
      expect(participant.status, equals(EventRsvpStatus.going));
    });
  });
}

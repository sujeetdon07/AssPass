import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/businesses/data/models/business_model.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_category.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_entity.dart';
import 'package:aaspaas/features/businesses/domain/entities/operating_hours.dart';

void main() {
  group('BusinessCategory', () {
    test('fromString parses categories correctly', () {
      expect(
        BusinessCategory.fromString('food_dining'),
        BusinessCategory.foodDining,
      );
      expect(
        BusinessCategory.fromString('grocery'),
        BusinessCategory.grocery,
      );
      expect(
        BusinessCategory.fromString('health'),
        BusinessCategory.health,
      );
      expect(
        BusinessCategory.fromString('beauty'),
        BusinessCategory.beauty,
      );
      expect(
        BusinessCategory.fromString('home_repair'),
        BusinessCategory.homeRepair,
      );
      expect(
        BusinessCategory.fromString('other'),
        BusinessCategory.other,
      );
    });

    test('fromString falls back to other for unknown/null', () {
      expect(BusinessCategory.fromString(null), BusinessCategory.other);
      expect(BusinessCategory.fromString('random_cat'), BusinessCategory.other);
    });
  });

  group('BusinessStatus & VerificationStatus', () {
    test('BusinessStatus.fromString handles valid and fallback values', () {
      expect(BusinessStatus.fromString('active'), BusinessStatus.active);
      expect(BusinessStatus.fromString('inactive'), BusinessStatus.inactive);
      expect(BusinessStatus.fromString('archived'), BusinessStatus.archived);
      expect(BusinessStatus.fromString(null), BusinessStatus.active);
      expect(BusinessStatus.fromString('invalid'), BusinessStatus.active);
    });

    test('BusinessVerificationStatus.fromString handles values', () {
      expect(
        BusinessVerificationStatus.fromString('unverified'),
        BusinessVerificationStatus.unverified,
      );
      expect(
        BusinessVerificationStatus.fromString('verified'),
        BusinessVerificationStatus.verified,
      );
      expect(
        BusinessVerificationStatus.fromString(null),
        BusinessVerificationStatus.unverified,
      );
    });
  });

  group('OperatingHoursEntity', () {
    test('fromJson & toJson round-trip', () {
      final json = {
        'monday': {
          'isClosed': false,
          'intervals': [
            {'open': '09:00', 'close': '21:00'},
          ],
        },
        'sunday': {
          'isClosed': true,
          'intervals': <Map<String, dynamic>>[],
        },
      };

      final hours = OperatingHoursEntity.fromJson(json);
      expect(hours.monday?.isClosed, false);
      expect(hours.monday?.intervals.first.open, '09:00');
      expect(hours.monday?.intervals.first.close, '21:00');
      expect(hours.sunday?.isClosed, true);
      expect(hours.sunday?.intervals.isEmpty, true);

      final serialized = hours.toJson();
      expect(serialized['monday']['isClosed'], false);
      expect(serialized['sunday']['isClosed'], true);
    });
  });

  group('BusinessModel', () {
    test('fromJson parses full business model correctly', () {
      final json = {
        'id': 'b-101',
        'ownerId': 'user-1',
        'name': 'Green Leaf Cafe',
        'slug': 'green-leaf-cafe',
        'description': 'Fresh organic brews and pastries in Indiranagar.',
        'category': 'food_dining',
        'status': 'active',
        'verificationStatus': 'verified',
        'countryCode': 'IN',
        'city': 'Bengaluru',
        'locality': 'Indiranagar',
        'address': '100ft Road',
        'contactPhone': '+918012345678',
        'contactEmail': 'hello@greenleaf.in',
        'website': 'https://greenleaf.in',
        'timezone': 'Asia/Kolkata',
        'favoriteCount': 12,
        'isFavorited': true,
        'isOwner': false,
        'distance': '1.2 km',
        'distanceMeters': 1200,
        'owner': {
          'id': 'user-1',
          'displayName': 'Ravi Patel',
          'avatarUrl': 'https://example.com/avatar.jpg',
          'locality': 'Indiranagar',
          'city': 'Bengaluru',
        },
        'images': [
          {
            'id': 'img-1',
            'url': 'https://example.com/cafe.jpg',
            'displayOrder': 0,
          }
        ],
        'services': [
          {
            'id': 'svc-1',
            'name': 'Espresso',
            'description': 'Double shot',
            'startingPrice': 120,
            'currency': 'INR',
          }
        ],
        'operatingHours': {
          'monday': {
            'isClosed': false,
            'intervals': [
              {'open': '08:00', 'close': '20:00'},
            ],
          },
        },
        'operatingStatus': {
          'isOpen': true,
          'status': 'open_now',
          'statusText': 'Open Now',
          'closesAt': '20:00',
        },
        'createdAt': '2026-09-23T10:00:00.000Z',
        'updatedAt': '2026-09-23T10:00:00.000Z',
      };

      final business = BusinessModel.fromJson(json);

      expect(business.id, 'b-101');
      expect(business.name, 'Green Leaf Cafe');
      expect(business.category, BusinessCategory.foodDining);
      expect(business.status, BusinessStatus.active);
      expect(business.verificationStatus, BusinessVerificationStatus.verified);
      expect(business.locationSummary, 'Indiranagar, Bengaluru');
      expect(business.primaryImageUrl, 'https://example.com/cafe.jpg');
      expect(business.operatingStatus.isOpen, true);
      expect(business.operatingStatus.statusText, 'Open Now');
      expect(business.services.length, 1);
      expect(business.services.first.name, 'Espresso');
      expect(business.services.first.startingPrice, 120.0);
      expect(business.owner.displayName, 'Ravi Patel');
      expect(business.isFavorited, true);
      expect(business.favoriteCount, 12);
    });

    test('PaginatedBusinessesModel parses items and cursor', () {
      final json = {
        'items': [
          {
            'id': 'b-1',
            'ownerId': 'user-1',
            'name': 'Local Shop',
            'slug': 'local-shop',
            'description': 'A small shop',
            'category': 'shopping',
            'status': 'active',
            'verificationStatus': 'unverified',
            'operatingStatus': {
              'isOpen': false,
              'status': 'closed',
              'statusText': 'Closed',
            },
            'createdAt': '2026-09-23T10:00:00.000Z',
            'updatedAt': '2026-09-23T10:00:00.000Z',
          }
        ],
        'nextCursor': 'cursor-xyz',
        'hasMore': true,
      };

      final page = PaginatedBusinessesModel.fromJson(json);
      expect(page.items.length, 1);
      expect(page.items.first.name, 'Local Shop');
      expect(page.nextCursor, 'cursor-xyz');
      expect(page.hasMore, true);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/marketplace/data/models/marketplace_listing_model.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_category.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_condition.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_status.dart';

void main() {
  group('MarketplaceCategory', () {
    test('fromString parses all standard categories correctly', () {
      expect(
        MarketplaceCategory.fromString('furniture'),
        MarketplaceCategory.furniture,
      );
      expect(
        MarketplaceCategory.fromString('electronics'),
        MarketplaceCategory.electronics,
      );
      expect(
        MarketplaceCategory.fromString('vehicles'),
        MarketplaceCategory.vehicles,
      );
      expect(
        MarketplaceCategory.fromString('home_kitchen'),
        MarketplaceCategory.homeKitchen,
      );
      expect(
        MarketplaceCategory.fromString('fashion'),
        MarketplaceCategory.fashion,
      );
      expect(
        MarketplaceCategory.fromString('books'),
        MarketplaceCategory.books,
      );
      expect(
        MarketplaceCategory.fromString('kids'),
        MarketplaceCategory.kids,
      );
      expect(
        MarketplaceCategory.fromString('sports'),
        MarketplaceCategory.sports,
      );
      expect(
        MarketplaceCategory.fromString('other'),
        MarketplaceCategory.other,
      );
    });

    test('fromString fallback to other on null or unknown string', () {
      expect(MarketplaceCategory.fromString(null), MarketplaceCategory.other);
      expect(
        MarketplaceCategory.fromString('unknown_category'),
        MarketplaceCategory.other,
      );
    });
  });

  group('MarketplaceCondition', () {
    test('fromString parses all conditions correctly', () {
      expect(
        MarketplaceCondition.fromString('new'),
        MarketplaceCondition.brandNew,
      );
      expect(
        MarketplaceCondition.fromString('like_new'),
        MarketplaceCondition.likeNew,
      );
      expect(
        MarketplaceCondition.fromString('good'),
        MarketplaceCondition.good,
      );
      expect(
        MarketplaceCondition.fromString('fair'),
        MarketplaceCondition.fair,
      );
      expect(
        MarketplaceCondition.fromString('used'),
        MarketplaceCondition.used,
      );
    });

    test('fromString fallback to good on null or unknown', () {
      expect(MarketplaceCondition.fromString(null), MarketplaceCondition.good);
      expect(
        MarketplaceCondition.fromString('random_cond'),
        MarketplaceCondition.good,
      );
    });
  });

  group('MarketplaceListingStatus', () {
    test('fromString parses all statuses correctly', () {
      expect(
        MarketplaceListingStatus.fromString('active'),
        MarketplaceListingStatus.active,
      );
      expect(
        MarketplaceListingStatus.fromString('sold'),
        MarketplaceListingStatus.sold,
      );
      expect(
        MarketplaceListingStatus.fromString('archived'),
        MarketplaceListingStatus.archived,
      );
    });

    test('fromString fallback to active on unknown', () {
      expect(
        MarketplaceListingStatus.fromString(null),
        MarketplaceListingStatus.active,
      );
      expect(
        MarketplaceListingStatus.fromString('unknown_status'),
        MarketplaceListingStatus.active,
      );
    });
  });

  group('MarketplaceListingModel', () {
    test('fromJson & toEntity correctly parse standard listing json', () {
      final json = <String, dynamic>{
        'id': 'list-100',
        'sellerId': 'user-100',
        'seller': {
          'id': 'user-100',
          'displayName': 'Aarav Sharma',
          'avatarUrl': 'https://aaspaas.in/avatars/aarav.jpg',
          'locality': 'Indiranagar',
          'city': 'Bengaluru',
        },
        'title': 'Ergonomic Wooden Desk',
        'description': 'Solid sheesham wood desk in mint condition.',
        'category': 'furniture',
        'price': '3500.00',
        'currency': 'INR',
        'condition': 'like_new',
        'status': 'active',
        'countryCode': 'IN',
        'state': 'Karnataka',
        'district': 'Bengaluru Urban',
        'city': 'Bengaluru',
        'locality': 'Indiranagar',
        'neighborhood': '12th Main',
        'favoriteCount': 12,
        'isFavorited': true,
        'isOwner': false,
        'images': [
          {
            'id': 'img-1',
            'url': 'https://aaspaas.in/listings/desk1.jpg',
            'displayOrder': 0,
          },
        ],
        'distance': '1.4 km',
        'distanceMeters': 1400,
        'createdAt': '2026-09-01T10:00:00.000Z',
        'updatedAt': '2026-09-01T10:00:00.000Z',
      };

      final model = MarketplaceListingModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.id, 'list-100');
      expect(entity.title, 'Ergonomic Wooden Desk');
      expect(entity.category, MarketplaceCategory.furniture);
      expect(entity.condition, MarketplaceCondition.likeNew);
      expect(entity.status, MarketplaceListingStatus.active);
      expect(entity.price, 3500.0);
      expect(entity.isFree, false);
      expect(entity.formattedPrice, '₹3500');
      expect(entity.locality, 'Indiranagar');
      expect(entity.favoriteCount, 12);
      expect(entity.isFavorited, true);
      expect(entity.isOwner, false);
      expect(entity.images.length, 1);
      expect(entity.images.first.url, 'https://aaspaas.in/listings/desk1.jpg');
      expect(entity.seller.displayName, 'Aarav Sharma');
      expect(entity.distance, '1.4 km');
    });

    test('Free giveaway item format and status flags', () {
      final json = <String, dynamic>{
        'id': 'list-200',
        'sellerId': 'user-200',
        'title': 'Free College Textbooks',
        'description': 'NCERT and engineering physics books free for students.',
        'category': 'books',
        'price': 0,
        'currency': 'INR',
        'condition': 'good',
        'status': 'sold',
        'city': 'Bengaluru',
        'locality': 'Koramangala',
        'favoriteCount': 5,
        'isFavorited': false,
        'isOwner': true,
        'images': <Map<String, dynamic>>[],
      };

      final entity = MarketplaceListingModel.fromJson(json).toEntity();

      expect(entity.id, 'list-200');
      expect(entity.isFree, true);
      expect(entity.formattedPrice, 'Free');
      expect(entity.isSold, true);
      expect(entity.isActive, false);
      expect(entity.isOwner, true);
      expect(entity.primaryImageUrl, isNull);
    });

    test('MarketplaceListingPageModel parses pagination list', () {
      final pageJson = <String, dynamic>{
        'items': <Map<String, dynamic>>[
          {
            'id': 'list-1',
            'sellerId': 'user-1',
            'title': 'Item 1',
            'description': 'Description 1',
            'category': 'electronics',
            'price': 1200,
            'condition': 'good',
            'status': 'active',
          },
          {
            'id': 'list-2',
            'sellerId': 'user-2',
            'title': 'Item 2',
            'description': 'Description 2',
            'category': 'furniture',
            'price': 4000,
            'condition': 'new',
            'status': 'archived',
          },
        ],
        'nextCursor': 'cursor-token-xyz',
        'hasMore': true,
      };

      final page = MarketplaceListingPageModel.fromJson(pageJson);
      expect(page.items.length, 2);
      expect(page.items[0].id, 'list-1');
      expect(page.items[1].isArchived, true);
      expect(page.nextCursor, 'cursor-token-xyz');
      expect(page.hasMore, true);
    });
  });
}

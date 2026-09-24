import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/services/data/models/service_listing_model.dart';
import 'package:aaspaas/features/services/domain/entities/service_category.dart';

void main() {
  group('ServiceCategory', () {
    test('fromString parses all categories correctly', () {
      expect(
        ServiceCategory.fromString('electrician'),
        ServiceCategory.electrician,
      );
      expect(
        ServiceCategory.fromString('plumber'),
        ServiceCategory.plumber,
      );
      expect(
        ServiceCategory.fromString('carpenter'),
        ServiceCategory.carpenter,
      );
      expect(
        ServiceCategory.fromString('cleaner'),
        ServiceCategory.cleaner,
      );
      expect(
        ServiceCategory.fromString('tutor'),
        ServiceCategory.tutor,
      );
      expect(
        ServiceCategory.fromString('other'),
        ServiceCategory.other,
      );
    });

    test('fromString falls back to other for unknown/empty', () {
      expect(ServiceCategory.fromString('unknown_category'),
          ServiceCategory.other,);
      expect(ServiceCategory.fromString(''), ServiceCategory.other);
    });
  });

  group('PricingModel', () {
    test('fromString parses pricing models correctly', () {
      expect(PricingModel.fromString('fixed'), PricingModel.fixed);
      expect(PricingModel.fromString('hourly'), PricingModel.hourly);
      expect(PricingModel.fromString('starting_at'), PricingModel.startingAt);
      expect(
        PricingModel.fromString('contact_for_quote'),
        PricingModel.contactForQuote,
      );
    });

    test('fromString falls back to contactForQuote', () {
      expect(PricingModel.fromString('random_model'),
          PricingModel.contactForQuote,);
    });
  });

  group('ServiceListingModel', () {
    test('fromJson parses full service model correctly', () {
      final json = {
        'id': 'svc-101',
        'providerId': 'user-2',
        'title': 'Reliable Home Plumbing & Pipe Fitting',
        'description':
            'Over 8 years solving leaks, geyser fittings, and blockages.',
        'category': 'plumber',
        'pricingModel': 'hourly',
        'startingPrice': 350.0,
        'currency': 'INR',
        'experienceYears': 8,
        'status': 'active',
        'countryCode': 'IN',
        'city': 'Bengaluru',
        'locality': 'Koramangala',
        'serviceRadiusKm': 10.0,
        'serviceAreaDescription': 'Serving Koramangala, HSR, and BTM Layout',
        'contactPhone': '+919876543210',
        'contactWhatsapp': '+919876543210',
        'contactEmail': 'plumber@local.in',
        'favoriteCount': 5,
        'isFavorited': true,
        'isProvider': false,
        'distance': '2.4 km',
        'distanceMeters': 2400,
        'provider': {
          'id': 'user-2',
          'displayName': 'Suresh Kumar',
          'avatarUrl': 'https://example.com/suresh.jpg',
          'locality': 'Koramangala',
          'city': 'Bengaluru',
        },
        'createdAt': '2026-09-23T10:00:00.000Z',
        'updatedAt': '2026-09-23T10:00:00.000Z',
      };

      final service = ServiceListingModel.fromJson(json);

      expect(service.id, 'svc-101');
      expect(service.title, 'Reliable Home Plumbing & Pipe Fitting');
      expect(service.category, ServiceCategory.plumber);
      expect(service.pricingModel, PricingModel.hourly);
      expect(service.startingPrice, 350.0);
      expect(service.experienceYears, 8);
      expect(service.status, ServiceStatus.active);
      expect(service.provider.displayName, 'Suresh Kumar');
      expect(service.locationSummary, 'Koramangala, Bengaluru');
      expect(service.formattedPrice, '₹350/hr');
      expect(service.serviceRadiusKm, 10.0);
      expect(service.isFavorited, true);
      expect(service.favoriteCount, 5);
    });

    test('formattedPrice formats according to pricing model', () {
      final baseJson = {
        'id': 'svc-1',
        'providerId': 'p-1',
        'title': 'Test Service',
        'description': 'Description',
        'category': 'cleaner',
        'status': 'active',
        'provider': {'id': 'p-1', 'displayName': 'Cleaner'},
        'createdAt': '2026-09-23T10:00:00.000Z',
        'updatedAt': '2026-09-23T10:00:00.000Z',
      };

      final fixed = ServiceListingModel.fromJson({
        ...baseJson,
        'pricingModel': 'fixed',
        'startingPrice': 500,
      });
      expect(fixed.formattedPrice, '₹500');

      final startingAt = ServiceListingModel.fromJson({
        ...baseJson,
        'pricingModel': 'starting_at',
        'startingPrice': 299,
      });
      expect(startingAt.formattedPrice, 'From ₹299');

      final quote = ServiceListingModel.fromJson({
        ...baseJson,
        'pricingModel': 'contact_for_quote',
      });
      expect(quote.formattedPrice, 'Contact for quote');
    });

    test('PaginatedServicesModel parses items and cursor', () {
      final json = {
        'items': [
          {
            'id': 'svc-1',
            'providerId': 'p-1',
            'title': 'Maths Tutoring',
            'description': 'Grades 6-10',
            'category': 'tutor',
            'pricingModel': 'hourly',
            'startingPrice': 400,
            'status': 'active',
            'provider': {'id': 'p-1', 'displayName': 'Teacher'},
            'createdAt': '2026-09-23T10:00:00.000Z',
            'updatedAt': '2026-09-23T10:00:00.000Z',
          }
        ],
        'nextCursor': 'cursor-abc',
        'hasMore': true,
      };

      final page = PaginatedServicesModel.fromJson(json);
      expect(page.items.length, 1);
      expect(page.items.first.title, 'Maths Tutoring');
      expect(page.nextCursor, 'cursor-abc');
      expect(page.hasMore, true);
    });
  });
}

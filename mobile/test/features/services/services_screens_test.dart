import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/theme/app_icons.dart';
import 'package:aaspaas/features/services/domain/entities/service_category.dart';
import 'package:aaspaas/features/services/domain/entities/service_filter.dart';
import 'package:aaspaas/features/services/domain/entities/service_listing_entity.dart';
import 'package:aaspaas/features/services/presentation/widgets/report_service_dialog.dart';
import 'package:aaspaas/features/services/presentation/widgets/service_card.dart';
import 'package:aaspaas/features/services/presentation/widgets/service_filter_sheet.dart';

ServiceListingEntity _createService({
  String id = 'svc-1',
  String title = 'Complete House Deep Cleaning',
  ServiceCategory category = ServiceCategory.cleaner,
  PricingModel pricingModel = PricingModel.fixed,
  double startingPrice = 1499,
  int experienceYears = 4,
  String locality = 'Koramangala',
  bool isFavorited = false,
}) {
  return ServiceListingEntity(
    id: id,
    providerId: 'user-provider-1',
    provider: const ServiceProviderEntity(
      id: 'user-provider-1',
      displayName: 'Anita Cleaners',
      locality: 'Koramangala',
      city: 'Bengaluru',
    ),
    title: title,
    description: 'Eco-friendly deep cleaning for 1BHK, 2BHK, 3BHK homes.',
    category: category,
    pricingModel: pricingModel,
    startingPrice: startingPrice,
    experienceYears: experienceYears,
    status: ServiceStatus.active,
    locality: locality,
    city: 'Bengaluru',
    isFavorited: isFavorited,
    favoriteCount: 8,
    distance: '2.0 km',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('ServiceCard Widget', () {
    testWidgets('renders service information, price, experience, and provider',
        (tester) async {
      final service = _createService();
      bool favToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: ServiceCard(
                  service: service,
                  onFavoriteToggle: () => favToggled = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Complete House Deep Cleaning'), findsOneWidget);
      expect(find.text('Cleaning & Housekeeping'), findsOneWidget);
      expect(find.text('₹1499'), findsOneWidget);
      expect(find.text('4y exp'), findsOneWidget);
      expect(find.text('Anita Cleaners'), findsOneWidget);
      expect(find.textContaining('Koramangala'), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.likeOutline));
      expect(favToggled, true);
    });
  });

  group('ServiceFilterSheet Widget', () {
    testWidgets('renders categories, pricing models, and applies filter',
        (tester) async {
      ServiceFilter? appliedFilter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceFilterSheet(
              initialFilter: const ServiceFilter(),
              onApply: (filter) => appliedFilter = filter,
            ),
          ),
        ),
      );

      expect(find.text('Filter Services'), findsOneWidget);
      expect(find.text('Service Category'), findsOneWidget);
      expect(find.text('Pricing Structure'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);

      // Select category
      await tester.tap(find.text('Electrician'));
      await tester.pumpAndSettle();

      // Select pricing model
      await tester.tap(find.text('Hourly Rate'));
      await tester.pumpAndSettle();

      // Tap Apply
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(appliedFilter, isNotNull);
      expect(appliedFilter?.category, ServiceCategory.electrician);
      expect(appliedFilter?.pricingModel, PricingModel.hourly);
    });
  });

  group('ReportServiceDialog Widget', () {
    testWidgets('renders reasons and submits report', (tester) async {
      bool reportCalled = false;
      String? reportedReason;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportServiceDialog(
              serviceId: 'svc-1',
              serviceTitle: 'House Cleaning',
              onSubmit: (reason, details) async {
                reportCalled = true;
                reportedReason = reason;
              },
            ),
          ),
        ),
      );

      expect(find.text('Report Service'), findsOneWidget);
      expect(find.textContaining('House Cleaning'), findsOneWidget);

      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      expect(reportCalled, true);
      expect(reportedReason, 'incorrect_info');
    });
  });
}

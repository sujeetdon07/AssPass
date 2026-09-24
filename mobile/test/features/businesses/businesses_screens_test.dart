import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/theme/app_icons.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_category.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_entity.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_filter.dart';
import 'package:aaspaas/features/businesses/domain/entities/operating_hours.dart';
import 'package:aaspaas/features/businesses/presentation/widgets/business_card.dart';
import 'package:aaspaas/features/businesses/presentation/widgets/business_filter_sheet.dart';
import 'package:aaspaas/features/businesses/presentation/widgets/report_business_dialog.dart';

BusinessEntity _createBusiness({
  String id = 'b-1',
  String name = 'Nandi Corner Bakery',
  BusinessCategory category = BusinessCategory.foodDining,
  String locality = 'Indiranagar',
  bool isFavorited = false,
  bool isOpen = true,
  String statusText = 'Open Now',
}) {
  return BusinessEntity(
    id: id,
    ownerId: 'user-owner-1',
    owner: const BusinessOwnerEntity(
      id: 'user-owner-1',
      displayName: 'Ravi P',
      locality: 'Indiranagar',
      city: 'Bengaluru',
    ),
    name: name,
    slug: 'nandi-corner-bakery',
    description: 'Fresh local puffs, buns, and filter coffee.',
    category: category,
    status: BusinessStatus.active,
    verificationStatus: BusinessVerificationStatus.verified,
    locality: locality,
    city: 'Bengaluru',
    operatingStatus: OperatingStatusEntity(
      isOpen: isOpen,
      status: isOpen ? 'open_now' : 'closed',
      statusText: statusText,
    ),
    isFavorited: isFavorited,
    favoriteCount: 15,
    distance: '1.2 km',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('BusinessCard Widget', () {
    testWidgets('renders business information, status pill, and category',
        (tester) async {
      final business = _createBusiness();
      bool favToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: BusinessCard(
                  business: business,
                  onFavoriteToggle: () => favToggled = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nandi Corner Bakery'), findsOneWidget);
      expect(find.text('Food & Dining'), findsWidgets);
      expect(find.text('Open Now'), findsOneWidget);
      expect(find.textContaining('Indiranagar'), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.likeOutline));
      expect(favToggled, true);
    });

    testWidgets('renders closed status pill correctly', (tester) async {
      final business = _createBusiness(
        isOpen: false,
        statusText: 'Closed',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: BusinessCard(
                  business: business,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Closed'), findsOneWidget);
    });
  });

  group('BusinessFilterSheet Widget', () {
    testWidgets('renders categories, inputs, and applies updated filter',
        (tester) async {
      BusinessFilter? appliedFilter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusinessFilterSheet(
              initialFilter: const BusinessFilter(),
              onApply: (filter) => appliedFilter = filter,
            ),
          ),
        ),
      );

      expect(find.text('Filter Businesses'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Open Now'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);

      // Select category
      await tester.tap(find.text('Grocery & Essentials'));
      await tester.pumpAndSettle();

      // Tap Apply
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(appliedFilter, isNotNull);
      expect(appliedFilter?.category, BusinessCategory.grocery);
    });
  });

  group('ReportBusinessDialog Widget', () {
    testWidgets('renders reasons and submits report', (tester) async {
      bool reportCalled = false;
      String? reportedReason;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportBusinessDialog(
              businessId: 'b-1',
              businessName: 'Nandi Bakery',
              onSubmit: (reason, details) async {
                reportCalled = true;
                reportedReason = reason;
              },
            ),
          ),
        ),
      );

      expect(find.text('Report Business'), findsOneWidget);
      expect(find.textContaining('Nandi Bakery'), findsOneWidget);

      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      expect(reportCalled, true);
      expect(reportedReason, 'incorrect_info');
    });
  });
}

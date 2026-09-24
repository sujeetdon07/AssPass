import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/theme/app_icons.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_category.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_condition.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_filter.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_listing_entity.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_status.dart';
import 'package:aaspaas/features/marketplace/domain/entities/seller_profile_entity.dart';
import 'package:aaspaas/features/marketplace/presentation/widgets/listing_card.dart';
import 'package:aaspaas/features/marketplace/presentation/widgets/listing_status_chip.dart';
import 'package:aaspaas/features/marketplace/presentation/widgets/marketplace_filter_sheet.dart';

MarketplaceListingEntity _createListing({
  String id = 'item-1',
  String title = 'Solid Sheesham Dining Table',
  double price = 6500,
  MarketplaceCondition condition = MarketplaceCondition.good,
  MarketplaceListingStatus status = MarketplaceListingStatus.active,
  String locality = 'Indiranagar',
  bool isFavorited = false,
  int favoriteCount = 7,
}) {
  return MarketplaceListingEntity(
    id: id,
    sellerId: 'user-seller-1',
    seller: const SellerProfileEntity(
      id: 'user-seller-1',
      displayName: 'Pooja V',
      locality: 'Indiranagar',
      city: 'Bengaluru',
    ),
    title: title,
    description: '6 seater dining table with minor scratches.',
    category: MarketplaceCategory.furniture,
    price: price,
    currency: 'INR',
    condition: condition,
    status: status,
    locality: locality,
    city: 'Bengaluru',
    favoriteCount: favoriteCount,
    isFavorited: isFavorited,
    isOwner: false,
    images: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('ListingStatusChip Widget', () {
    testWidgets('renders active status correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ListingStatusChip(status: MarketplaceListingStatus.active),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders sold status correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ListingStatusChip(status: MarketplaceListingStatus.sold),
          ),
        ),
      );

      expect(find.text('Sold'), findsOneWidget);
    });

    testWidgets('renders archived status correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ListingStatusChip(status: MarketplaceListingStatus.archived),
          ),
        ),
      );

      expect(find.text('Archived'), findsOneWidget);
    });
  });

  group('ListingCard Widget', () {
    testWidgets('renders standard listing information', (tester) async {
      final listing = _createListing();
      bool tapped = false;
      bool favoriteToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                height: 320,
                child: ListingCard(
                  listing: listing,
                  onTap: () => tapped = true,
                  onFavoritePressed: () => favoriteToggled = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Solid Sheesham Dining Table'), findsOneWidget);
      expect(find.text('₹6500'), findsOneWidget);
      expect(find.text('Indiranagar'), findsOneWidget);
      expect(find.text('Good Condition'), findsOneWidget);

      await tester.tap(find.text('Solid Sheesham Dining Table'));
      expect(tapped, true);

      await tester.tap(find.byIcon(AppIcons.likeOutline));
      expect(favoriteToggled, true);
    });

    testWidgets('renders Free text when item is a giveaway', (tester) async {
      final listing = _createListing(
        price: 0,
        title: 'Free Plant Cuttings',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                height: 320,
                child: ListingCard(
                  listing: listing,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Free Plant Cuttings'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets('renders Sold overlay badge when item is sold', (tester) async {
      final listing = _createListing(
        status: MarketplaceListingStatus.sold,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                height: 320,
                child: ListingCard(
                  listing: listing,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('SOLD'), findsOneWidget);
    });
  });

  group('MarketplaceFilterSheet Widget', () {
    testWidgets('renders filter options and allows applying changes',
        (tester) async {
      MarketplaceFilter? appliedFilter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => MarketplaceFilterSheet(
                      initialFilter: const MarketplaceFilter(),
                      onApply: (f) => appliedFilter = f,
                    ),
                  );
                },
                child: const Text('Open Filters'),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Filters & Sorting'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Item Condition'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);

      // Tap on Furniture chip
      await tester.tap(find.text('Furniture'));
      await tester.pumpAndSettle();

      // Ensure Apply button is visible in scrollable sheet, then tap
      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(appliedFilter, isNotNull);
      expect(appliedFilter?.category, MarketplaceCategory.furniture);
    });
  });
}

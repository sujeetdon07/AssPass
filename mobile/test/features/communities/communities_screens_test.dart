import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/communities/domain/entities/community_category.dart';
import 'package:aaspaas/features/communities/domain/entities/community_entity.dart';
import 'package:aaspaas/features/communities/presentation/widgets/community_card.dart';
import 'package:aaspaas/features/communities/presentation/widgets/community_category_chips.dart';
import 'package:aaspaas/features/communities/presentation/widgets/community_header.dart';

CommunityEntity createTestEntity({
  String id = 'comm-1',
  String name = 'Bangalore Techies',
  String description = 'A local tech community for neighborhood builders',
  CommunityCategory category = CommunityCategory.localInterests,
  bool currentUserMember = false,
  String? currentUserRole,
  bool isPrivate = false,
  int memberCount = 25,
  int postCount = 10,
}) {
  return CommunityEntity(
    id: id,
    name: name,
    slug: 'bangalore-techies',
    description: description,
    category: category,
    visibility: isPrivate ? 'private' : 'public',
    creatorId: 'user-tech-1',
    creatorName: 'Karthik R',
    locality: 'Koramangala',
    city: 'Bengaluru',
    memberCount: memberCount,
    postCount: postCount,
    currentUserMember: currentUserMember,
    currentUserRole: currentUserRole,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('CommunityCard Widget', () {
    testWidgets('renders community details, category, and counts',
        (tester) async {
      final comm = createTestEntity();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityCard(
              community: comm,
            ),
          ),
        ),
      );

      expect(find.text('Bangalore Techies'), findsOneWidget);
      expect(
        find.text('A local tech community for neighborhood builders'),
        findsOneWidget,
      );
      expect(find.text('25 members'), findsOneWidget);
      expect(find.text('10 posts'), findsOneWidget);
      expect(find.text('Koramangala, Bengaluru'), findsOneWidget);
    });

    testWidgets('renders Join button when not a member and Joined when member',
        (tester) async {
      final notMember = createTestEntity(currentUserMember: false);
      final member = createTestEntity(currentUserMember: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CommunityCard(
                  community: notMember,
                  onJoinToggle: () {},
                ),
                CommunityCard(
                  community: member,
                  onJoinToggle: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Joined'), findsOneWidget);
    });

    testWidgets('renders Private badge for private communities',
        (tester) async {
      final privateComm = createTestEntity(isPrivate: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityCard(community: privateComm),
          ),
        ),
      );

      expect(find.text('Private'), findsOneWidget);
    });
  });

  group('CommunityCategoryChips Widget', () {
    testWidgets('renders all chips and triggers callback', (tester) async {
      CommunityCategory? selectedCat;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityCategoryChips(
              selectedCategory: selectedCat,
              onCategorySelected: (cat) => selectedCat = cat,
            ),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Society / Apartment'), findsOneWidget);
      expect(find.text('Parents & Family'), findsOneWidget);

      await tester.tap(find.text('Parents & Family'));
      await tester.pump();

      expect(selectedCat, CommunityCategory.parentsFamily);
    });
  });

  group('CommunityHeader Widget', () {
    testWidgets('renders owner badge and action buttons', (tester) async {
      final comm = createTestEntity(
        currentUserMember: true,
        currentUserRole: 'owner',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityHeader(
              community: comm,
              onJoinToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Bangalore Techies'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('Owner (Manage)'), findsOneWidget);
    });
  });
}

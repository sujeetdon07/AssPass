import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/communities/data/models/communities_page_model.dart';
import 'package:aaspaas/features/communities/data/models/community_member_model.dart';
import 'package:aaspaas/features/communities/data/models/community_model.dart';
import 'package:aaspaas/features/communities/domain/entities/community_category.dart';
import 'package:aaspaas/features/feed/data/models/post_model.dart';

void main() {
  group('CommunityCategory', () {
    test('fromString maps known categories correctly', () {
      expect(
        CommunityCategory.fromString('society'),
        CommunityCategory.society,
      );
      expect(
        CommunityCategory.fromString('parents_family'),
        CommunityCategory.parentsFamily,
      );
      expect(
        CommunityCategory.fromString('local_interests'),
        CommunityCategory.localInterests,
      );
      expect(
        CommunityCategory.fromString('sports'),
        CommunityCategory.sports,
      );
      expect(
        CommunityCategory.fromString('hobbies'),
        CommunityCategory.hobbies,
      );
      expect(
        CommunityCategory.fromString('residents'),
        CommunityCategory.residents,
      );
      expect(
        CommunityCategory.fromString('local_help'),
        CommunityCategory.localHelp,
      );
    });

    test('fromString falls back correctly', () {
      expect(
        CommunityCategory.fromString(null),
        CommunityCategory.neighborhood,
      );
      expect(
        CommunityCategory.fromString('non_existent_category'),
        CommunityCategory.other,
      );
    });
  });

  group('CommunityModel', () {
    test('fromJson and toEntity parse backend response accurately', () {
      final json = {
        'id': 'comm-101',
        'name': 'Indiranagar Resident Welfare',
        'slug': 'indiranagar-resident-welfare',
        'description': 'Official community for residents of Indiranagar.',
        'category': 'society',
        'visibility': 'public',
        'status': 'active',
        'creatorId': 'user-1',
        'creatorName': 'Arun Sharma',
        'locality': 'Indiranagar',
        'neighborhood': 'Defence Colony',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'countryCode': 'IN',
        'memberCount': 42,
        'postCount': 15,
        'currentUserMember': true,
        'currentUserRole': 'owner',
        'createdAt': '2026-09-01T10:00:00Z',
        'updatedAt': '2026-09-02T12:00:00Z',
      };

      final model = CommunityModel.fromJson(json);
      expect(model.id, 'comm-101');
      expect(model.name, 'Indiranagar Resident Welfare');
      expect(model.slug, 'indiranagar-resident-welfare');
      expect(model.category, CommunityCategory.society);
      expect(model.memberCount, 42);
      expect(model.postCount, 15);
      expect(model.currentUserMember, isTrue);
      expect(model.currentUserRole, 'owner');

      final entity = model.toEntity();
      expect(entity.id, 'comm-101');
      expect(entity.isOwner, isTrue);
      expect(entity.isModerator, isTrue);
      expect(entity.isPrivate, isFalse);
      expect(entity.locationDisplay, 'Defence Colony, Indiranagar');
    });

    test('Private community helper flags', () {
      final json = {
        'id': 'comm-priv',
        'name': 'Apartment Tower A',
        'slug': 'tower-a',
        'description': 'Residents only',
        'category': 'society',
        'visibility': 'private',
        'creatorId': 'user-2',
        'memberCount': 5,
        'postCount': 2,
        'currentUserMember': false,
        'createdAt': '2026-09-01T10:00:00Z',
        'updatedAt': '2026-09-02T12:00:00Z',
      };

      final entity = CommunityModel.fromJson(json).toEntity();
      expect(entity.isPrivate, isTrue);
      expect(entity.currentUserMember, isFalse);
      expect(entity.isOwner, isFalse);
    });
  });

  group('CommunityMemberModel', () {
    test('fromJson and toEntity parse accurately with role badges', () {
      final json = {
        'id': 'mem-1',
        'communityId': 'comm-101',
        'userId': 'usr-88',
        'displayName': 'Priya Patel',
        'locality': 'Indiranagar',
        'city': 'Bengaluru',
        'role': 'moderator',
        'status': 'active',
        'joinedAt': '2026-09-10T08:00:00Z',
      };

      final member = CommunityMemberModel.fromJson(json).toEntity();
      expect(member.id, 'mem-1');
      expect(member.displayName, 'Priya Patel');
      expect(member.isModerator, isTrue);
      expect(member.isOwner, isFalse);
      expect(member.locationSummary, 'Indiranagar, Bengaluru');
    });
  });

  group('CommunitiesPageModel', () {
    test('parses paginated list with hasMore and cursor', () {
      final json = {
        'communities': [
          {
            'id': 'c-1',
            'name': 'Comm 1',
            'slug': 'c-1',
            'description': 'Desc 1',
            'category': 'general',
            'creatorId': 'u-1',
            'memberCount': 10,
            'postCount': 3,
            'createdAt': '2026-09-01T10:00:00Z',
            'updatedAt': '2026-09-01T10:00:00Z',
          }
        ],
        'hasMore': true,
        'nextCursor': 'cursor-xyz',
      };

      final page = CommunitiesPageModel.fromJson(json);
      expect(page.communities.length, 1);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'cursor-xyz');
    });
  });

  group('PostModel with Community Metadata', () {
    test('parses communityId, communityName, and communitySlug', () {
      final json = {
        'id': 'post-comm-1',
        'content': 'Meeting tomorrow at club house',
        'category': 'announcement',
        'authorId': 'u-10',
        'author': {
          'id': 'u-10',
          'displayName': 'Secretary',
        },
        'communityId': 'comm-101',
        'communityName': 'Palm Meadows Society',
        'communitySlug': 'palm-meadows-society',
        'likeCount': 3,
        'commentCount': 1,
        'currentUserLiked': true,
        'createdAt': '2026-09-15T10:00:00Z',
        'updatedAt': '2026-09-15T10:00:00Z',
      };

      final post = PostModel.fromJson(json).toEntity();
      expect(post.communityId, 'comm-101');
      expect(post.communityName, 'Palm Meadows Society');
      expect(post.communitySlug, 'palm-meadows-society');
      expect(post.currentUserLiked, isTrue);
    });
  });
}

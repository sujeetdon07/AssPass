import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
} from '@nestjs/common';
import { CommunitiesService } from '../../src/modules/communities/services/communities.service.js';
import {
  Community,
  CommunityCategory,
  CommunityVisibility,
  CommunityStatus,
} from '../../src/modules/communities/entities/community.entity.js';
import {
  CommunityRole,
  CommunityMemberStatus,
} from '../../src/modules/communities/entities/community-member.entity.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';
import { PostCategory } from '../../src/modules/feed/entities/post.entity.js';
import { ReportReason } from '../../src/modules/feed/entities/report.entity.js';
import { CommunityDiscoveryScope } from '../../src/modules/communities/dto/get-communities-query.dto.js';

describe('CommunitiesService', () => {
  let service: CommunitiesService;
  let mockCommRepo: any;
  let mockMemberRepo: any;
  let mockPostRepo: any;
  let mockUserRepo: any;
  let mockReportRepo: any;
  let mockRedisService: any;

  const mockUserA: User = {
    id: 'usr-a',
    phoneNumber: '+919999900001',
    displayName: 'Aakash Verma',
    avatarUrl: null,
    accountStatus: UserStatus.ACTIVE,
    onboardingCompleted: true,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: 'Defence Colony',
    createdAt: new Date(),
    updatedAt: new Date(),
    sessions: [],
  };

  const mockUserB: User = {
    id: 'usr-b',
    phoneNumber: '+919999900002',
    displayName: 'Priya Sharma',
    avatarUrl: null,
    accountStatus: UserStatus.ACTIVE,
    onboardingCompleted: true,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: '100ft road',
    createdAt: new Date(),
    updatedAt: new Date(),
    sessions: [],
  };

  const mockCommunity: Community = {
    id: 'comm-1',
    name: 'Indiranagar Resident Club',
    slug: 'indiranagar-resident-club',
    description: 'A community for residents of Indiranagar.',
    category: CommunityCategory.NEIGHBORHOOD,
    visibility: CommunityVisibility.PUBLIC,
    status: CommunityStatus.ACTIVE,
    creatorId: mockUserA.id,
    creator: mockUserA,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: 'Defence Colony',
    memberCount: 1,
    postCount: 0,
    coverImageUrl: null,
    avatarUrl: null,
    createdAt: new Date('2026-09-22T10:00:00.000Z'),
    updatedAt: new Date('2026-09-22T10:00:00.000Z'),
  };

  beforeEach(() => {
    mockCommRepo = {
      findOne: vi.fn(),
      find: vi.fn(),
      create: vi.fn((data: any) => ({ ...data, id: 'comm-1', createdAt: new Date(), updatedAt: new Date() })),
      save: vi.fn((c: any) => Promise.resolve(c)),
      increment: vi.fn().mockResolvedValue(undefined),
      decrement: vi.fn().mockResolvedValue(undefined),
      createQueryBuilder: vi.fn(),
    };

    mockMemberRepo = {
      findOne: vi.fn(),
      find: vi.fn(),
      create: vi.fn((data: any) => ({ ...data, id: 'member-1', joinedAt: new Date(), updatedAt: new Date() })),
      save: vi.fn((m: any) => Promise.resolve(m)),
      remove: vi.fn().mockResolvedValue(undefined),
      createQueryBuilder: vi.fn(),
    };

    mockPostRepo = {
      findOne: vi.fn(),
      create: vi.fn((data: any) => ({ ...data, id: 'post-1', createdAt: new Date(), updatedAt: new Date() })),
      save: vi.fn((p: any) => Promise.resolve(p)),
      createQueryBuilder: vi.fn(),
    };

    mockUserRepo = {
      findOne: vi.fn(),
    };

    mockReportRepo = {
      findOne: vi.fn(),
      create: vi.fn((data: any) => ({ ...data, id: 'rep-1', createdAt: new Date() })),
      save: vi.fn((r: any) => Promise.resolve(r)),
    };

    mockRedisService = {
      get: vi.fn().mockResolvedValue(null),
      set: vi.fn().mockResolvedValue('OK'),
      ttl: vi.fn().mockResolvedValue(3600),
      incr: vi.fn().mockResolvedValue(1),
      expire: vi.fn().mockResolvedValue(1),
      del: vi.fn().mockResolvedValue(1),
    };

    service = new CommunitiesService(
      mockCommRepo,
      mockMemberRepo,
      mockPostRepo,
      mockUserRepo,
      mockReportRepo,
      mockRedisService,
    );
  });

  describe('createCommunity', () => {
    it('creates community, sets creator as OWNER member, and defaults locality', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockUserA);
      mockCommRepo.findOne.mockResolvedValue(null); // No slug collision

      const res = await service.createCommunity(mockUserA.id, {
        name: 'Indiranagar Resident Club',
        description: 'A community for residents of Indiranagar.',
        category: CommunityCategory.NEIGHBORHOOD,
      });

      expect(res.name).toBe('Indiranagar Resident Club');
      expect(res.slug).toBe('indiranagar-resident-club');
      expect(res.currentUserMember).toBe(true);
      expect(res.currentUserRole).toBe(CommunityRole.OWNER);
      expect(res.memberCount).toBe(1);
      expect(mockCommRepo.save).toHaveBeenCalled();
      expect(mockMemberRepo.save).toHaveBeenCalled();
    });

    it('rejects creation when rate limit exceeded', async () => {
      mockRedisService.incr.mockResolvedValue(11); // Max reached (10)

      await expect(
        service.createCommunity(mockUserA.id, {
          name: 'Indiranagar Resident Club',
          description: 'A community for residents of Indiranagar.',
          category: CommunityCategory.NEIGHBORHOOD,
        }),
      ).rejects.toThrow(HttpException);
    });
  });

  describe('getCommunities', () => {
    it('returns paginated communities list with membership flags', async () => {
      mockUserRepo.findOne.mockResolvedValue(mockUserA);
      const mockQb = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        leftJoin: vi.fn().mockReturnThis(),
        addSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        addOrderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getRawAndEntities: vi.fn().mockResolvedValue({
          entities: [mockCommunity],
          raw: [{ currentUserMember: true, currentUserRole: CommunityRole.OWNER }],
        }),
      };
      mockCommRepo.createQueryBuilder.mockReturnValue(mockQb);

      const res = await service.getCommunities(mockUserA.id, {
        scope: CommunityDiscoveryScope.ALL,
        limit: 20,
      });

      expect(res.communities.length).toBe(1);
      expect(res.communities[0].name).toBe('Indiranagar Resident Club');
      expect(res.communities[0].currentUserMember).toBe(true);
      expect(res.communities[0].currentUserRole).toBe(CommunityRole.OWNER);
    });
  });

  describe('getCommunityById', () => {
    it('returns community details with current user membership info', async () => {
      mockCommRepo.findOne.mockResolvedValue(mockCommunity);
      mockMemberRepo.findOne.mockResolvedValue({
        id: 'mem-1',
        communityId: mockCommunity.id,
        userId: mockUserA.id,
        role: CommunityRole.OWNER,
        status: CommunityMemberStatus.ACTIVE,
      });

      const res = await service.getCommunityById(mockCommunity.id, mockUserA.id);

      expect(res.id).toBe(mockCommunity.id);
      expect(res.currentUserMember).toBe(true);
      expect(res.currentUserRole).toBe(CommunityRole.OWNER);
    });

    it('throws NotFoundException if community does not exist', async () => {
      mockCommRepo.findOne.mockResolvedValue(null);

      await expect(
        service.getCommunityById('non-existent-id', mockUserA.id),
      ).rejects.toThrow(NotFoundException);
    });

    it('throws ForbiddenException if community is suspended', async () => {
      mockCommRepo.findOne.mockResolvedValue({
        ...mockCommunity,
        status: CommunityStatus.SUSPENDED,
      });

      await expect(
        service.getCommunityById(mockCommunity.id, mockUserA.id),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('updateCommunity', () => {
    it('allows community OWNER to update community details', async () => {
      mockCommRepo.findOne.mockResolvedValue({ ...mockCommunity });
      mockMemberRepo.findOne.mockResolvedValue({
        id: 'mem-1',
        communityId: mockCommunity.id,
        userId: mockUserA.id,
        role: CommunityRole.OWNER,
        status: CommunityMemberStatus.ACTIVE,
      });

      const res = await service.updateCommunity(mockCommunity.id, mockUserA.id, {
        description: 'New updated description for Indiranagar.',
      });

      expect(res.description).toBe('New updated description for Indiranagar.');
      expect(mockCommRepo.save).toHaveBeenCalled();
    });

    it('rejects update if user is normal MEMBER or not authorized', async () => {
      mockCommRepo.findOne.mockResolvedValue({ ...mockCommunity });
      mockMemberRepo.findOne.mockResolvedValue({
        id: 'mem-2',
        communityId: mockCommunity.id,
        userId: mockUserB.id,
        role: CommunityRole.MEMBER,
        status: CommunityMemberStatus.ACTIVE,
      });

      await expect(
        service.updateCommunity(mockCommunity.id, mockUserB.id, {
          description: 'Hacked description',
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('joinCommunity', () => {
    it('allows a user to join a public active community and increments memberCount', async () => {
      mockCommRepo.findOne.mockResolvedValue({ ...mockCommunity });
      mockMemberRepo.findOne.mockResolvedValue(null); // not already member

      const res = await service.joinCommunity(mockCommunity.id, mockUserB.id);

      expect(res.message).toContain('Successfully joined');
      expect(res.role).toBe(CommunityRole.MEMBER);
      expect(mockMemberRepo.save).toHaveBeenCalled();
      expect(mockCommRepo.increment).toHaveBeenCalledWith(
        { id: mockCommunity.id },
        'memberCount',
        1,
      );
    });

    it('handles idempotent join if user is already an active member', async () => {
      mockCommRepo.findOne.mockResolvedValue({ ...mockCommunity });
      mockMemberRepo.findOne.mockResolvedValue({
        id: 'mem-2',
        communityId: mockCommunity.id,
        userId: mockUserB.id,
        role: CommunityRole.MEMBER,
        status: CommunityMemberStatus.ACTIVE,
      });

      const res = await service.joinCommunity(mockCommunity.id, mockUserB.id);

      expect(res.message).toContain('already a member');
      expect(mockMemberRepo.save).not.toHaveBeenCalled();
      expect(mockCommRepo.increment).not.toHaveBeenCalled();
    });

    it('rejects joining a suspended community', async () => {
      mockCommRepo.findOne.mockResolvedValue({
        ...mockCommunity,
        status: CommunityStatus.SUSPENDED,
      });

      await expect(
        service.joinCommunity(mockCommunity.id, mockUserB.id),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('leaveCommunity', () => {
    it('allows a member to leave community and decrements memberCount', async () => {
      const memberRecord = {
        id: 'mem-2',
        communityId: mockCommunity.id,
        userId: mockUserB.id,
        role: CommunityRole.MEMBER,
        status: CommunityMemberStatus.ACTIVE,
      };
      mockMemberRepo.findOne.mockResolvedValue(memberRecord);

      const res = await service.leaveCommunity(mockCommunity.id, mockUserB.id);

      expect(res.message).toContain('Successfully left');
      expect(mockMemberRepo.remove).toHaveBeenCalledWith(memberRecord);
      expect(mockCommRepo.decrement).toHaveBeenCalledWith(
        { id: mockCommunity.id },
        'memberCount',
        1,
      );
    });

    it('rejects leave request if current user is community OWNER', async () => {
      mockMemberRepo.findOne.mockResolvedValue({
        id: 'mem-1',
        communityId: mockCommunity.id,
        userId: mockUserA.id,
        role: CommunityRole.OWNER,
        status: CommunityMemberStatus.ACTIVE,
      });

      await expect(
        service.leaveCommunity(mockCommunity.id, mockUserA.id),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('getMembers authorization & privacy', () => {
    it('returns privacy-safe member list for public community', async () => {
      mockCommRepo.findOne.mockResolvedValue(mockCommunity);
      const mockQb = {
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        addOrderBy: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([
          {
            id: 'mem-1',
            communityId: mockCommunity.id,
            userId: mockUserA.id,
            role: CommunityRole.OWNER,
            status: CommunityMemberStatus.ACTIVE,
            user: mockUserA,
            joinedAt: new Date(),
          },
        ]),
      };
      mockMemberRepo.createQueryBuilder.mockReturnValue(mockQb);

      const res = await service.getMembers(mockCommunity.id, mockUserB.id);

      expect(res.members.length).toBe(1);
      expect(res.members[0].user.displayName).toBe('Aakash Verma');
      expect((res.members[0].user as any).phoneNumber).toBeUndefined();
      expect((res.members[0].user as any).email).toBeUndefined();
    });

    it('blocks non-members from viewing members of a private community', async () => {
      mockCommRepo.findOne.mockResolvedValue({
        ...mockCommunity,
        visibility: CommunityVisibility.PRIVATE,
      });
      mockMemberRepo.findOne.mockResolvedValue(null); // User B is not a member

      await expect(
        service.getMembers(mockCommunity.id, mockUserB.id),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('getCommunityPosts authorization', () => {
    it('blocks non-members from viewing posts in a private community', async () => {
      mockCommRepo.findOne.mockResolvedValue({
        ...mockCommunity,
        visibility: CommunityVisibility.PRIVATE,
      });
      mockMemberRepo.findOne.mockResolvedValue(null); // non-member

      await expect(
        service.getCommunityPosts(mockCommunity.id, mockUserB.id),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('createCommunityPost authorization', () => {
    it('allows active members to post in community', async () => {
      mockCommRepo.findOne.mockResolvedValue(mockCommunity);
      mockMemberRepo.findOne.mockResolvedValue({
        id: 'mem-2',
        communityId: mockCommunity.id,
        userId: mockUserB.id,
        role: CommunityRole.MEMBER,
        status: CommunityMemberStatus.ACTIVE,
      });
      mockUserRepo.findOne.mockResolvedValue(mockUserB);

      const res = await service.createCommunityPost(mockCommunity.id, mockUserB.id, {
        content: 'Hello fellow Indiranagar residents!',
        category: PostCategory.GENERAL,
      });

      expect(res.content).toBe('Hello fellow Indiranagar residents!');
      expect(res.communityId).toBe(mockCommunity.id);
      expect(res.community?.name).toBe('Indiranagar Resident Club');
      expect(mockPostRepo.save).toHaveBeenCalled();
      expect(mockCommRepo.increment).toHaveBeenCalledWith(
        { id: mockCommunity.id },
        'postCount',
        1,
      );
    });

    it('rejects post creation if user is NOT a member of the community', async () => {
      mockCommRepo.findOne.mockResolvedValue(mockCommunity);
      mockMemberRepo.findOne.mockResolvedValue(null); // not a member

      await expect(
        service.createCommunityPost(mockCommunity.id, mockUserB.id, {
          content: 'Hello non-member!',
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('reportCommunity', () => {
    it('submits a report against a community', async () => {
      mockCommRepo.findOne.mockResolvedValue(mockCommunity);
      mockReportRepo.findOne.mockResolvedValue(null); // not already reported

      const res = await service.reportCommunity(mockCommunity.id, mockUserB.id, {
        reason: ReportReason.SPAM,
        details: 'Spam community with fake links',
      });

      expect(res.message).toContain('submitted for review');
      expect(mockReportRepo.save).toHaveBeenCalled();
    });

    it('rejects duplicate report from same reporter', async () => {
      mockCommRepo.findOne.mockResolvedValue(mockCommunity);
      mockReportRepo.findOne.mockResolvedValue({ id: 'rep-existing' });

      await expect(
        service.reportCommunity(mockCommunity.id, mockUserB.id, {
          reason: ReportReason.SPAM,
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('Community Lifecycle & Status', () => {
    it('prevents joining a suspended community', async () => {
      mockCommRepo.findOne.mockResolvedValue({
        ...mockCommunity,
        status: CommunityStatus.SUSPENDED,
      });

      await expect(
        service.joinCommunity(mockCommunity.id, mockUserB.id),
      ).rejects.toThrow(ForbiddenException);
    });

    it('prevents posting to a suspended community', async () => {
      mockCommRepo.findOne.mockResolvedValue({
        ...mockCommunity,
        status: CommunityStatus.SUSPENDED,
      });

      await expect(
        service.createCommunityPost(mockCommunity.id, mockUserA.id, {
          content: 'Hello to suspended group',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows owner to archive an active community', async () => {
      const activeComm = { ...mockCommunity, status: CommunityStatus.ACTIVE };
      mockCommRepo.findOne.mockResolvedValue(activeComm);
      mockMemberRepo.findOne.mockResolvedValue({
        communityId: mockCommunity.id,
        userId: mockUserA.id,
        role: CommunityRole.OWNER,
        status: CommunityMemberStatus.ACTIVE,
      });
      mockCommRepo.save.mockImplementation(async (c: any) => c);

      const res = await service.updateCommunity(mockCommunity.id, mockUserA.id, {
        status: CommunityStatus.ARCHIVED,
      });

      expect(res.status).toBe(CommunityStatus.ARCHIVED);
    });

    it('prevents regular owner from suspending community directly', async () => {
      mockCommRepo.findOne.mockResolvedValue({ ...mockCommunity, status: CommunityStatus.ACTIVE });
      mockMemberRepo.findOne.mockResolvedValue({
        communityId: mockCommunity.id,
        userId: mockUserA.id,
        role: CommunityRole.OWNER,
        status: CommunityMemberStatus.ACTIVE,
      });

      await expect(
        service.updateCommunity(mockCommunity.id, mockUserA.id, {
          status: CommunityStatus.SUSPENDED,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('prevents editing a suspended community', async () => {
      mockCommRepo.findOne.mockResolvedValue({ ...mockCommunity, status: CommunityStatus.SUSPENDED });

      await expect(
        service.updateCommunity(mockCommunity.id, mockUserA.id, {
          name: 'Renamed Suspended Club',
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});


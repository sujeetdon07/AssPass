import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
} from '@nestjs/common';
import { MarketplaceService } from '../../src/modules/marketplace/services/marketplace.service.js';
import {
  MarketplaceListing,
  MarketplaceCategory,
  MarketplaceCondition,
  MarketplaceListingStatus,
} from '../../src/modules/marketplace/entities/marketplace-listing.entity.js';
import { MarketplaceReportReason } from '../../src/modules/marketplace/entities/marketplace-report.entity.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';

describe('MarketplaceService', () => {
  let service: MarketplaceService;
  let mockListingRepo: any;
  let mockImageRepo: any;
  let mockFavRepo: any;
  let mockReportRepo: any;
  let mockUserRepo: any;
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
  };

  const mockListing: MarketplaceListing = {
    id: 'lst-1',
    sellerId: 'usr-a',
    seller: mockUserA,
    title: 'Solid Wood Study Table',
    description: 'Beautiful Sheesham wood study table with two drawers in excellent condition.',
    category: MarketplaceCategory.FURNITURE,
    price: 4500,
    currency: 'INR',
    condition: MarketplaceCondition.LIKE_NEW,
    status: MarketplaceListingStatus.ACTIVE,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: 'Defence Colony',
    favoriteCount: 1,
    images: [],
    createdAt: new Date('2026-09-20T10:00:00Z'),
    updatedAt: new Date('2026-09-20T10:00:00Z'),
  };

  beforeEach(() => {
    mockListingRepo = {
      create: vi.fn((data) => ({ ...data, id: 'lst-generated-id', createdAt: new Date(), updatedAt: new Date() })),
      save: vi.fn(async (entity) => ({ ...entity, id: entity.id || 'lst-generated-id', createdAt: entity.createdAt || new Date(), updatedAt: new Date() })),
      findOne: vi.fn(async ({ where }) => {
        if (where?.id === 'lst-1') return { ...mockListing };
        return null;
      }),
      query: vi.fn(async () => []),
      softDelete: vi.fn(async () => ({ affected: 1 })),
      increment: vi.fn(async () => ({ affected: 1 })),
      decrement: vi.fn(async () => ({ affected: 1 })),
      createQueryBuilder: vi.fn(),
    };

    mockImageRepo = {
      create: vi.fn((data) => ({ ...data, id: 'img-1', createdAt: new Date() })),
      save: vi.fn(async (entities) => (Array.isArray(entities) ? entities : [entities])),
      delete: vi.fn(async () => ({ affected: 1 })),
      createQueryBuilder: vi.fn(() => ({
        where: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        getMany: vi.fn(async () => []),
      })),
    };

    mockFavRepo = {
      create: vi.fn((data) => ({ ...data, id: 'fav-1', createdAt: new Date() })),
      save: vi.fn(async (fav) => fav),
      findOne: vi.fn(async () => null),
      remove: vi.fn(async (fav) => fav),
      createQueryBuilder: vi.fn(),
    };

    mockReportRepo = {
      create: vi.fn((data) => ({ ...data, id: 'rep-1', createdAt: new Date() })),
      save: vi.fn(async (rep) => rep),
      findOne: vi.fn(async () => null),
    };

    mockUserRepo = {
      findOne: vi.fn(async ({ where }) => {
        if (where?.id === 'usr-a') return mockUserA;
        if (where?.id === 'usr-b') return mockUserB;
        return null;
      }),
    };

    mockRedisService = {
      get: vi.fn(async () => null),
      set: vi.fn(async () => 'OK'),
      ttl: vi.fn(async () => 3600),
      incr: vi.fn(async () => 1),
      expire: vi.fn(async () => 1),
      del: vi.fn(async () => 1),
    };

    service = new MarketplaceService(
      mockListingRepo,
      mockImageRepo,
      mockFavRepo,
      mockReportRepo,
      mockUserRepo,
      mockRedisService,
    );
  });

  describe('Listing Creation', () => {
    it('creates a listing successfully with valid inputs', async () => {
      const result = await service.createListing('usr-a', {
        title: 'Solid Wood Study Table',
        description: 'Handcrafted study table in great condition.',
        category: MarketplaceCategory.FURNITURE,
        price: 4500,
        condition: MarketplaceCondition.LIKE_NEW,
        locality: 'Indiranagar',
        city: 'Bengaluru',
      });

      expect(result).toBeDefined();
      expect(result.title).toBe('Solid Wood Study Table');
      expect(result.price).toBe(4500);
      expect(result.category).toBe(MarketplaceCategory.FURNITURE);
      expect(result.condition).toBe(MarketplaceCondition.LIKE_NEW);
      expect(result.isOwner).toBe(true);
      expect(mockListingRepo.save).toHaveBeenCalled();
    });

    it('rejects listing creation if user does not exist', async () => {
      await expect(
        service.createListing('non-existent-user', {
          title: 'Mechanical Keyboard',
          description: 'Custom mechanical keyboard with tactile switches.',
          category: MarketplaceCategory.COMPUTERS,
          price: 3200,
          condition: MarketplaceCondition.GOOD,
        }),
      ).rejects.toThrow(NotFoundException);
    });

    it('enforces rate limiting on listing creation', async () => {
      mockRedisService.incr.mockResolvedValueOnce(25); // limit is 20/hr

      await expect(
        service.createListing('usr-a', {
          title: 'Mechanical Keyboard',
          description: 'Custom mechanical keyboard with tactile switches.',
          category: MarketplaceCategory.COMPUTERS,
          price: 3200,
          condition: MarketplaceCondition.GOOD,
        }),
      ).rejects.toThrow(HttpException);
    });
  });

  describe('Ownership & Status Transitions', () => {
    it('allows listing owner to edit listing details', async () => {
      const updated = await service.updateListing('lst-1', 'usr-a', {
        title: 'Sheesham Wood Table (Price Reduced)',
        price: 3800,
      });

      expect(updated.title).toBe('Sheesham Wood Table (Price Reduced)');
      expect(updated.price).toBe(3800);
      expect(mockListingRepo.save).toHaveBeenCalled();
    });

    it('forbids non-owner from updating a listing', async () => {
      await expect(
        service.updateListing('lst-1', 'usr-b', {
          title: 'Hacked Title',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows listing owner to update status to SOLD', async () => {
      const result = await service.updateListingStatus(
        'lst-1',
        'usr-a',
        MarketplaceListingStatus.SOLD,
      );

      expect(result.status).toBe(MarketplaceListingStatus.SOLD);
      expect(mockListingRepo.save).toHaveBeenCalled();
    });

    it('allows listing owner to update status to ARCHIVED', async () => {
      const result = await service.updateListingStatus(
        'lst-1',
        'usr-a',
        MarketplaceListingStatus.ARCHIVED,
      );

      expect(result.status).toBe(MarketplaceListingStatus.ARCHIVED);
    });

    it('allows listing owner to update status to SOLD and relist back to ACTIVE', async () => {
      const soldRes = await service.updateListingStatus(
        'lst-1',
        'usr-a',
        MarketplaceListingStatus.SOLD,
      );
      expect(soldRes.status).toBe(MarketplaceListingStatus.SOLD);

      const activeRes = await service.updateListingStatus(
        'lst-1',
        'usr-a',
        MarketplaceListingStatus.ACTIVE,
      );
      expect(activeRes.status).toBe(MarketplaceListingStatus.ACTIVE);
    });

    it('forbids non-owner from changing status of a listing', async () => {
      await expect(
        service.updateListingStatus(
          'lst-1',
          'usr-b',
          MarketplaceListingStatus.SOLD,
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows listing owner to delete their own listing (soft delete)', async () => {
      const res = await service.deleteListing('lst-1', 'usr-a');
      expect(res.message).toContain('deleted');
      expect(mockListingRepo.softDelete).toHaveBeenCalledWith('lst-1');
    });

    it('forbids non-owner from deleting another users listing', async () => {
      await expect(service.deleteListing('lst-1', 'usr-b')).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('Discovery & Privacy Projection', () => {
    it('returns listing details with privacy-safe seller projection (no phone or coordinates)', async () => {
      const detail = await service.getListingById('lst-1', 'usr-b');

      expect(detail.id).toBe('lst-1');
      expect(detail.title).toBe('Solid Wood Study Table');
      expect(detail.seller.displayName).toBe('Aakash Verma');
      expect(detail.seller.locality).toBe('Indiranagar');

      // Privacy audit: ensure no private fields exist in output
      const jsonStr = JSON.stringify(detail);
      expect(jsonStr).not.toContain('phoneNumber');
      expect(jsonStr).not.toContain('+91');
      expect(jsonStr).not.toContain('location');
      expect(jsonStr).not.toContain('coordinates');
    });

    it('throws NotFoundException when accessing non-existent or deleted listing', async () => {
      await expect(service.getListingById('unknown-id', 'usr-a')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('discovers listings with query builder filters and pagination', async () => {
      const mockRawRows = [
        {
          id: 'lst-1',
          sellerId: 'usr-a',
          title: 'Solid Wood Study Table',
          description: 'Description here',
          category: MarketplaceCategory.FURNITURE,
          price: '4500.00',
          currency: 'INR',
          condition: MarketplaceCondition.LIKE_NEW,
          status: MarketplaceListingStatus.ACTIVE,
          countryCode: 'IN',
          state: 'Karnataka',
          district: 'Bengaluru Urban',
          city: 'Bengaluru',
          locality: 'Indiranagar',
          neighborhood: null,
          favoriteCount: '3',
          createdAt: new Date(),
          updatedAt: new Date(),
          seller_id: 'usr-a',
          seller_displayName: 'Aakash Verma',
          seller_avatarUrl: null,
          seller_locality: 'Indiranagar',
          seller_city: 'Bengaluru',
          currentUserFavorited: false,
          distance_meters: '450',
        },
      ];

      const qb: any = {
        leftJoin: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        addSelect: vi.fn().mockReturnThis(),
        setParameters: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        addOrderBy: vi.fn().mockReturnThis(),
        limit: vi.fn().mockReturnThis(),
        getRawMany: vi.fn(async () => mockRawRows),
      };

      mockListingRepo.createQueryBuilder.mockReturnValue(qb);

      const result = await service.getListings('usr-b', {
        category: MarketplaceCategory.FURNITURE,
        minPrice: 1000,
        maxPrice: 10000,
        latitude: 12.9784,
        longitude: 77.6408,
        radius: 5,
      });

      expect(result.items.length).toBe(1);
      expect(result.items[0].id).toBe('lst-1');
      expect(result.items[0].price).toBe(4500);
      expect(result.items[0].distance).toBe('450 m away');
      expect(result.hasMore).toBe(false);
    });

    it('excludes archived listings from public discovery query', async () => {
      const qb: any = {
        leftJoin: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        addSelect: vi.fn().mockReturnThis(),
        setParameters: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        addOrderBy: vi.fn().mockReturnThis(),
        limit: vi.fn().mockReturnThis(),
        getRawMany: vi.fn(async () => []),
      };

      mockListingRepo.createQueryBuilder.mockReturnValue(qb);

      await service.getListings('usr-b', {
        status: MarketplaceListingStatus.ARCHIVED,
      });

      expect(qb.andWhere).toHaveBeenCalledWith('listing.status != :archivedStatus', {
        archivedStatus: MarketplaceListingStatus.ARCHIVED,
      });
    });
  });

  describe('Favorites', () => {
    it('favorites a listing and increments favorite count', async () => {
      const res = await service.toggleFavorite('lst-1', 'usr-b', true);
      expect(res.isFavorited).toBe(true);
      expect(mockFavRepo.save).toHaveBeenCalled();
      expect(mockListingRepo.increment).toHaveBeenCalledWith({ id: 'lst-1' }, 'favoriteCount', 1);
    });

    it('unfavorites a listing and decrements favorite count', async () => {
      mockFavRepo.findOne.mockResolvedValueOnce({ id: 'fav-1', listingId: 'lst-1', userId: 'usr-b' });

      const res = await service.toggleFavorite('lst-1', 'usr-b', false);
      expect(res.isFavorited).toBe(false);
      expect(mockFavRepo.remove).toHaveBeenCalled();
      expect(mockListingRepo.decrement).toHaveBeenCalledWith({ id: 'lst-1' }, 'favoriteCount', 1);
    });

    it('retrieves user favorites excluding archived and deleted listings', async () => {
      const mockFavListings = [
        {
          id: 'fav-1',
          userId: 'usr-b',
          listingId: 'lst-1',
          createdAt: new Date('2026-09-21T10:00:00Z'),
          listing: {
            ...mockListing,
            seller: mockUserA,
            images: [],
          },
        },
      ];

      const qb: any = {
        innerJoinAndSelect: vi.fn().mockReturnThis(),
        leftJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        addOrderBy: vi.fn().mockReturnThis(),
        limit: vi.fn().mockReturnThis(),
        getMany: vi.fn(async () => mockFavListings),
      };

      mockFavRepo.createQueryBuilder.mockReturnValue(qb);

      const res = await service.getMyFavorites('usr-b');
      expect(res.items.length).toBe(1);
      expect(res.items[0].id).toBe('lst-1');
      expect(res.items[0].isFavorited).toBe(true);
      expect(qb.andWhere).toHaveBeenCalledWith('listing.status != :archivedStatus', {
        archivedStatus: MarketplaceListingStatus.ARCHIVED,
      });
      expect(qb.andWhere).toHaveBeenCalledWith('listing.deletedAt IS NULL');
    });
  });

  describe('Reports', () => {
    it('submits a report against a listing', async () => {
      const res = await service.reportListing('lst-1', 'usr-b', {
        reason: MarketplaceReportReason.SCAM,
        details: 'Seller asked for advance bank transfer before pickup.',
      });

      expect(res.message).toContain('submitted');
      expect(mockReportRepo.save).toHaveBeenCalled();
    });

    it('forbids reporting own listing', async () => {
      await expect(
        service.reportListing('lst-1', 'usr-a', {
          reason: MarketplaceReportReason.SPAM,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects duplicate reports from the same user for the same listing', async () => {
      mockReportRepo.findOne.mockResolvedValueOnce({
        id: 'rep-existing',
        listingId: 'lst-1',
        reporterId: 'usr-b',
      });

      await expect(
        service.reportListing('lst-1', 'usr-b', {
          reason: MarketplaceReportReason.SPAM,
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('enforces rate limit on reports', async () => {
      mockRedisService.incr.mockResolvedValueOnce(15); // limit is 10/hr

      await expect(
        service.reportListing('lst-1', 'usr-b', {
          reason: MarketplaceReportReason.SPAM,
        }),
      ).rejects.toThrow(HttpException);
    });
  });
});

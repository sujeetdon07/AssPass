import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
} from '@nestjs/common';
import { BusinessesService } from '../../src/modules/businesses/services/businesses.service.js';
import {
  Business,
  BusinessCategory,
  BusinessStatus,
  BusinessVerificationStatus,
} from '../../src/modules/businesses/entities/business.entity.js';
import { BusinessReportReason } from '../../src/modules/businesses/entities/business-report.entity.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';

describe('BusinessesService', () => {
  let service: BusinessesService;
  let mockBusinessRepo: any;
  let mockImageRepo: any;
  let mockServiceRepo: any;
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

  const mockBusiness: Business = {
    id: 'biz-1',
    ownerId: 'usr-a',
    owner: mockUserA,
    name: 'Artisan Bakery & Cafe',
    slug: 'artisan-bakery-cafe-abc123',
    description: 'Fresh artisanal sourdough, pastries, and specialty roasted espresso.',
    category: BusinessCategory.FOOD_DINING,
    status: BusinessStatus.ACTIVE,
    verificationStatus: BusinessVerificationStatus.UNVERIFIED,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: '12th Main',
    address: '12th Main Road, HAL 2nd Stage',
    contactPhone: '+918012345678',
    contactEmail: 'contact@artisanbakery.com',
    website: 'https://artisanbakery.in',
    timezone: 'Asia/Kolkata',
    operatingHours: {
      monday: { isClosed: false, intervals: [{ open: '08:00', close: '22:00' }] },
    },
    favoriteCount: 2,
    images: [],
    services: [],
    createdAt: new Date('2026-09-20T10:00:00Z'),
    updatedAt: new Date('2026-09-20T10:00:00Z'),
  };

  beforeEach(() => {
    mockBusinessRepo = {
      create: vi.fn((data) => ({
        ...data,
        id: 'biz-generated-id',
        createdAt: new Date(),
        updatedAt: new Date(),
      })),
      save: vi.fn(async (entity) => ({
        ...entity,
        id: entity.id || 'biz-generated-id',
        createdAt: entity.createdAt || new Date(),
        updatedAt: new Date(),
      })),
      findOne: vi.fn(async ({ where }) => {
        if (where?.id === 'biz-1') return { ...mockBusiness };
        return null;
      }),
      query: vi.fn(async () => []),
      softDelete: vi.fn(async () => ({ affected: 1 })),
      increment: vi.fn(async () => ({ affected: 1 })),
      decrement: vi.fn(async () => ({ affected: 1 })),
      createQueryBuilder: vi.fn(),
    };

    mockImageRepo = {
      create: vi.fn((data) => ({ ...data, id: 'img-generated-id', createdAt: new Date() })),
      save: vi.fn(async (entities) =>
        Array.isArray(entities)
          ? entities.map((e, idx) => ({ ...e, id: `img-${idx + 1}` }))
          : { ...entities, id: 'img-1' },
      ),
      delete: vi.fn(async () => ({ affected: 1 })),
      createQueryBuilder: vi.fn(() => ({
        where: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        getMany: vi.fn(async () => []),
      })),
    };

    mockServiceRepo = {
      create: vi.fn((data) => ({
        ...data,
        id: 'svc-generated-id',
        createdAt: new Date(),
        updatedAt: new Date(),
      })),
      save: vi.fn(async (entities) =>
        Array.isArray(entities)
          ? entities.map((e, idx) => ({ ...e, id: `svc-${idx + 1}` }))
          : { ...entities, id: 'svc-1' },
      ),
      delete: vi.fn(async () => ({ affected: 1 })),
      createQueryBuilder: vi.fn(() => ({
        where: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        getMany: vi.fn(async () => []),
      })),
    };

    mockFavRepo = {
      findOne: vi.fn(async () => null),
      create: vi.fn((data) => ({ ...data, id: 'fav-1', createdAt: new Date() })),
      save: vi.fn(async (data) => data),
      delete: vi.fn(async () => ({ affected: 1 })),
    };

    mockReportRepo = {
      findOne: vi.fn(async () => null),
      create: vi.fn((data) => ({ ...data, id: 'rep-1', createdAt: new Date() })),
      save: vi.fn(async (data) => data),
    };

    mockUserRepo = {
      findOne: vi.fn(async ({ where }) => {
        if (where?.id === 'usr-a') return mockUserA;
        if (where?.id === 'usr-b') return mockUserB;
        return null;
      }),
    };

    mockRedisService = {
      incr: vi.fn(async () => 1),
      expire: vi.fn(async () => 1),
    };

    service = new BusinessesService(
      mockBusinessRepo,
      mockImageRepo,
      mockServiceRepo,
      mockFavRepo,
      mockReportRepo,
      mockUserRepo,
      mockRedisService,
    );
  });

  describe('createBusiness', () => {
    it('creates a business with valid data, images, and services', async () => {
      const result = await service.createBusiness('usr-a', {
        name: 'The French Baker',
        category: BusinessCategory.FOOD_DINING,
        description: 'Traditional French baguettes and croissants in the neighborhood.',
        locality: 'Indiranagar',
        city: 'Bengaluru',
        contactPhone: '+919876543210',
        images: [{ url: 'https://example.com/baker.jpg', displayOrder: 0 }],
        services: [{ name: 'Custom Birthday Cakes', startingPrice: 850 }],
      });

      expect(result).toBeDefined();
      expect(result.name).toBe('The French Baker');
      expect(result.category).toBe(BusinessCategory.FOOD_DINING);
      expect(result.verificationStatus).toBe(BusinessVerificationStatus.UNVERIFIED);
      expect(result.isOwner).toBe(true);
      expect(mockBusinessRepo.save).toHaveBeenCalled();
      expect(mockBusinessRepo.query).toHaveBeenCalledWith(
        expect.stringContaining('ST_SetSRID(ST_MakePoint'),
        expect.any(Array),
      );
      expect(mockImageRepo.save).toHaveBeenCalled();
      expect(mockServiceRepo.save).toHaveBeenCalled();
    });

    it('rejects creation when user does not exist', async () => {
      await expect(
        service.createBusiness('usr-nonexistent', {
          name: 'Shop',
          category: BusinessCategory.GROCERY,
          description: 'A local grocery store.',
        }),
      ).rejects.toThrow(NotFoundException);
    });

    it('enforces rate limiting on creation', async () => {
      mockRedisService.incr = vi.fn(async () => 21); // exceeds max 20 per hour
      await expect(
        service.createBusiness('usr-a', {
          name: 'Shop 21',
          category: BusinessCategory.GROCERY,
          description: 'Another local shop.',
        }),
      ).rejects.toThrow(HttpException);
    });
  });

  describe('getBusinessById', () => {
    it('returns public business detail', async () => {
      const result = await service.getBusinessById('biz-1', 'usr-b');
      expect(result).toBeDefined();
      expect(result.id).toBe('biz-1');
      expect(result.name).toBe('Artisan Bakery & Cafe');
      expect(result.isOwner).toBe(false);
      expect(result.owner.id).toBe('usr-a');
    });

    it('throws 404 if business does not exist', async () => {
      await expect(service.getBusinessById('biz-999', 'usr-a')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('hides inactive businesses from non-owners', async () => {
      mockBusinessRepo.findOne = vi.fn(async () => ({
        ...mockBusiness,
        status: BusinessStatus.INACTIVE,
      }));

      await expect(service.getBusinessById('biz-1', 'usr-b')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('allows owner to view their own inactive business', async () => {
      mockBusinessRepo.findOne = vi.fn(async () => ({
        ...mockBusiness,
        status: BusinessStatus.INACTIVE,
      }));

      const result = await service.getBusinessById('biz-1', 'usr-a');
      expect(result).toBeDefined();
      expect(result.status).toBe(BusinessStatus.INACTIVE);
      expect(result.isOwner).toBe(true);
    });
  });

  describe('updateBusiness & updateBusinessStatus', () => {
    it('allows owner to update details', async () => {
      const result = await service.updateBusiness('biz-1', 'usr-a', {
        name: 'Artisan Bakery & Specialty Roasters',
      });
      expect(result).toBeDefined();
      expect(mockBusinessRepo.save).toHaveBeenCalled();
    });

    it('forbids non-owner from updating details (403)', async () => {
      await expect(
        service.updateBusiness('biz-1', 'usr-b', {
          name: 'Hacked Name',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows owner to update status', async () => {
      const result = await service.updateBusinessStatus('biz-1', 'usr-a', BusinessStatus.INACTIVE);
      expect(result.status).toBe(BusinessStatus.INACTIVE);
    });

    it('forbids non-owner from updating status (403)', async () => {
      await expect(
        service.updateBusinessStatus('biz-1', 'usr-b', BusinessStatus.ARCHIVED),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('deleteBusiness', () => {
    it('allows owner to soft delete business', async () => {
      const result = await service.deleteBusiness('biz-1', 'usr-a');
      expect(result.success).toBe(true);
      expect(mockBusinessRepo.softDelete).toHaveBeenCalledWith({ id: 'biz-1' });
    });

    it('forbids non-owner from deleting business (403)', async () => {
      await expect(service.deleteBusiness('biz-1', 'usr-b')).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('toggleFavorite', () => {
    it('favorites a business and increments count', async () => {
      const result = await service.toggleFavorite('biz-1', 'usr-b', true);
      expect(result.isFavorited).toBe(true);
      expect(result.favoriteCount).toBe(3);
      expect(mockFavRepo.save).toHaveBeenCalled();
      expect(mockBusinessRepo.increment).toHaveBeenCalledWith({ id: 'biz-1' }, 'favoriteCount', 1);
    });

    it('unfavorites a business and decrements count', async () => {
      mockFavRepo.findOne = vi.fn(async () => ({ id: 'fav-1', businessId: 'biz-1', userId: 'usr-b' }));
      const result = await service.toggleFavorite('biz-1', 'usr-b', false);
      expect(result.isFavorited).toBe(false);
      expect(result.favoriteCount).toBe(1);
      expect(mockFavRepo.delete).toHaveBeenCalled();
      expect(mockBusinessRepo.decrement).toHaveBeenCalledWith({ id: 'biz-1' }, 'favoriteCount', 1);
    });
  });

  describe('reportBusiness', () => {
    it('submits a moderation report for another user business', async () => {
      const result = await service.reportBusiness('biz-1', 'usr-b', {
        reason: BusinessReportReason.INCORRECT_INFO,
        details: 'Store moved to another street.',
      });
      expect(result.success).toBe(true);
      expect(mockReportRepo.save).toHaveBeenCalled();
    });

    it('prevents user from reporting their own business (400)', async () => {
      await expect(
        service.reportBusiness('biz-1', 'usr-a', {
          reason: BusinessReportReason.SPAM,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('prevents duplicate reports by the same user (409)', async () => {
      mockReportRepo.findOne = vi.fn(async () => ({ id: 'rep-existing' }));
      await expect(
        service.reportBusiness('biz-1', 'usr-b', {
          reason: BusinessReportReason.SPAM,
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('getCategories', () => {
    it('returns all 12 centralized business categories', () => {
      const categories = service.getCategories();
      expect(categories).toHaveLength(12);
      expect(categories.map((c) => c.id)).toContain(BusinessCategory.FOOD_DINING);
      expect(categories.map((c) => c.id)).toContain(BusinessCategory.GROCERY);
      expect(categories.map((c) => c.id)).toContain(BusinessCategory.HEALTH);
    });
  });
});

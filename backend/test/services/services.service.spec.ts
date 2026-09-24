import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
} from '@nestjs/common';
import { ServicesService } from '../../src/modules/services/services/services.service.js';
import {
  ServiceListing,
  ServiceCategory,
  ServiceStatus,
  ServiceVerificationStatus,
} from '../../src/modules/services/entities/service-listing.entity.js';
import { ServiceReportReason } from '../../src/modules/services/entities/service-report.entity.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';

describe('ServicesService', () => {
  let service: ServicesService;
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

  const mockServiceListing: ServiceListing = {
    id: 'svc-1',
    ownerId: 'usr-a',
    owner: mockUserA,
    title: 'Expert Home Electrician & Appliance Repair',
    description: 'Certified electrical wiring, short circuit fixes, fan and geyser installation.',
    category: ServiceCategory.HOME_REPAIR,
    status: ServiceStatus.ACTIVE,
    verificationStatus: ServiceVerificationStatus.UNVERIFIED,
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: 'Defence Colony',
    serviceRadiusKm: 10,
    contactPhone: '+919876543210',
    contactEmail: 'electrician.aakash@gmail.com',
    experienceYears: 8,
    availability: 'Mon–Sat 9:00 AM – 8:00 PM',
    startingPrice: 299,
    currency: 'INR',
    favoriteCount: 1,
    createdAt: new Date('2026-09-20T10:00:00Z'),
    updatedAt: new Date('2026-09-20T10:00:00Z'),
  };

  beforeEach(() => {
    mockServiceRepo = {
      create: vi.fn((data) => ({
        ...data,
        id: 'svc-generated-id',
        createdAt: new Date(),
        updatedAt: new Date(),
      })),
      save: vi.fn(async (entity) => ({
        ...entity,
        id: entity.id || 'svc-generated-id',
        createdAt: entity.createdAt || new Date(),
        updatedAt: new Date(),
      })),
      findOne: vi.fn(async ({ where }) => {
        if (where?.id === 'svc-1') return { ...mockServiceListing };
        return null;
      }),
      query: vi.fn(async () => []),
      softDelete: vi.fn(async () => ({ affected: 1 })),
      increment: vi.fn(async () => ({ affected: 1 })),
      decrement: vi.fn(async () => ({ affected: 1 })),
      createQueryBuilder: vi.fn(),
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

    service = new ServicesService(
      mockServiceRepo,
      mockFavRepo,
      mockReportRepo,
      mockUserRepo,
      mockRedisService,
    );
  });

  describe('createService', () => {
    it('creates a service listing with valid parameters', async () => {
      const result = await service.createService('usr-a', {
        title: 'Professional Home Plumbing',
        category: ServiceCategory.HOME_REPAIR,
        description: 'Complete pipeline fitting, leak stoppage, and tap repair.',
        locality: 'Indiranagar',
        city: 'Bengaluru',
        serviceRadiusKm: 15,
        startingPrice: 350,
      });

      expect(result).toBeDefined();
      expect(result.title).toBe('Professional Home Plumbing');
      expect(result.category).toBe(ServiceCategory.HOME_REPAIR);
      expect(result.verificationStatus).toBe(ServiceVerificationStatus.UNVERIFIED);
      expect(result.isOwner).toBe(true);
      expect(mockServiceRepo.save).toHaveBeenCalled();
      expect(mockServiceRepo.query).toHaveBeenCalledWith(
        expect.stringContaining('ST_SetSRID(ST_MakePoint'),
        expect.any(Array),
      );
    });

    it('rejects creation if user does not exist', async () => {
      await expect(
        service.createService('usr-nonexistent', {
          title: 'Tutor',
          category: ServiceCategory.EDUCATION,
          description: 'Math tutor.',
        }),
      ).rejects.toThrow(NotFoundException);
    });

    it('enforces creation rate limit', async () => {
      mockRedisService.incr = vi.fn(async () => 21);
      await expect(
        service.createService('usr-a', {
          title: 'Tutor',
          category: ServiceCategory.EDUCATION,
          description: 'Math tutor for high school.',
        }),
      ).rejects.toThrow(HttpException);
    });
  });

  describe('getServiceById', () => {
    it('returns public service details', async () => {
      const result = await service.getServiceById('svc-1', 'usr-b');
      expect(result).toBeDefined();
      expect(result.id).toBe('svc-1');
      expect(result.title).toBe('Expert Home Electrician & Appliance Repair');
      expect(result.isOwner).toBe(false);
      expect(result.owner.id).toBe('usr-a');
    });

    it('throws 404 if service does not exist', async () => {
      await expect(service.getServiceById('svc-999', 'usr-a')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('hides inactive services from non-owners', async () => {
      mockServiceRepo.findOne = vi.fn(async () => ({
        ...mockServiceListing,
        status: ServiceStatus.INACTIVE,
      }));

      await expect(service.getServiceById('svc-1', 'usr-b')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('updateService & updateServiceStatus', () => {
    it('allows owner to update service details', async () => {
      const result = await service.updateService('svc-1', 'usr-a', {
        title: 'Master Electrician & Emergency Repairs',
        startingPrice: 399,
      });
      expect(result).toBeDefined();
      expect(mockServiceRepo.save).toHaveBeenCalled();
    });

    it('forbids non-owner from updating service (403)', async () => {
      await expect(
        service.updateService('svc-1', 'usr-b', {
          title: 'Hacked Title',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows owner to update status', async () => {
      const result = await service.updateServiceStatus('svc-1', 'usr-a', ServiceStatus.INACTIVE);
      expect(result.status).toBe(ServiceStatus.INACTIVE);
    });

    it('forbids non-owner from updating status (403)', async () => {
      await expect(
        service.updateServiceStatus('svc-1', 'usr-b', ServiceStatus.ARCHIVED),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('deleteService', () => {
    it('allows owner to soft delete service', async () => {
      const result = await service.deleteService('svc-1', 'usr-a');
      expect(result.success).toBe(true);
      expect(mockServiceRepo.softDelete).toHaveBeenCalledWith({ id: 'svc-1' });
    });

    it('forbids non-owner from deleting service (403)', async () => {
      await expect(service.deleteService('svc-1', 'usr-b')).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('toggleFavorite', () => {
    it('favorites a service and increments count', async () => {
      const result = await service.toggleFavorite('svc-1', 'usr-b', true);
      expect(result.isFavorited).toBe(true);
      expect(result.favoriteCount).toBe(2);
      expect(mockFavRepo.save).toHaveBeenCalled();
      expect(mockServiceRepo.increment).toHaveBeenCalledWith({ id: 'svc-1' }, 'favoriteCount', 1);
    });

    it('unfavorites a service and decrements count', async () => {
      mockFavRepo.findOne = vi.fn(async () => ({ id: 'fav-1', serviceId: 'svc-1', userId: 'usr-b' }));
      const result = await service.toggleFavorite('svc-1', 'usr-b', false);
      expect(result.isFavorited).toBe(false);
      expect(result.favoriteCount).toBe(0);
      expect(mockFavRepo.delete).toHaveBeenCalled();
      expect(mockServiceRepo.decrement).toHaveBeenCalledWith({ id: 'svc-1' }, 'favoriteCount', 1);
    });
  });

  describe('reportService', () => {
    it('submits a report for a service listing', async () => {
      const result = await service.reportService('svc-1', 'usr-b', {
        reason: ServiceReportReason.INCORRECT_INFO,
        details: 'Service is no longer offered.',
      });
      expect(result.success).toBe(true);
      expect(mockReportRepo.save).toHaveBeenCalled();
    });

    it('prevents self-reporting (400)', async () => {
      await expect(
        service.reportService('svc-1', 'usr-a', {
          reason: ServiceReportReason.SPAM,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('prevents duplicate reports (409)', async () => {
      mockReportRepo.findOne = vi.fn(async () => ({ id: 'rep-existing' }));
      await expect(
        service.reportService('svc-1', 'usr-b', {
          reason: ServiceReportReason.SPAM,
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('getCategories', () => {
    it('returns all 9 centralized service categories', () => {
      const categories = service.getCategories();
      expect(categories).toHaveLength(9);
      expect(categories.map((c) => c.id)).toContain(ServiceCategory.HOME_REPAIR);
      expect(categories.map((c) => c.id)).toContain(ServiceCategory.EDUCATION);
      expect(categories.map((c) => c.id)).toContain(ServiceCategory.BEAUTY);
    });
  });
});

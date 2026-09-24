import { describe, it, expect, beforeEach, vi } from 'vitest';
import { BusinessesController } from '../../src/modules/businesses/businesses.controller.js';
import { BusinessCategory, BusinessStatus } from '../../src/modules/businesses/entities/business.entity.js';
import { BusinessReportReason } from '../../src/modules/businesses/entities/business-report.entity.js';

describe('BusinessesController', () => {
  let controller: BusinessesController;
  let mockBusinessesService: any;

  const mockUser = {
    userId: 'usr-test-1',
    phoneNumber: '+919999900001',
    onboardingCompleted: true,
  };

  beforeEach(() => {
    mockBusinessesService = {
      getCategories: vi.fn(() => []),
      getMyBusinesses: vi.fn(async () => ({ items: [], nextCursor: null, hasMore: false })),
      getBusinesses: vi.fn(async () => ({ items: [], nextCursor: null, hasMore: false })),
      createBusiness: vi.fn(async (userId, dto) => ({ id: 'biz-1', ...dto, ownerId: userId })),
      getBusinessById: vi.fn(async (id, userId) => ({ id, ownerId: userId })),
      updateBusiness: vi.fn(async (id, userId, dto) => ({ id, ...dto, ownerId: userId })),
      updateBusinessStatus: vi.fn(async (id, userId, status) => ({ id, status, ownerId: userId })),
      deleteBusiness: vi.fn(async (id, userId) => ({ success: true, message: 'Deleted' })),
      toggleFavorite: vi.fn(async (id, userId, fav) => ({ isFavorited: fav, favoriteCount: 1 })),
      reportBusiness: vi.fn(async (id, userId, dto) => ({ success: true, message: 'Reported' })),
    };

    controller = new BusinessesController(mockBusinessesService);
  });

  it('delegates getCategories to service', () => {
    controller.getCategories();
    expect(mockBusinessesService.getCategories).toHaveBeenCalled();
  });

  it('delegates getMyBusinesses to service', async () => {
    await controller.getMyBusinesses(mockUser, BusinessStatus.ACTIVE, 'cursor', 10);
    expect(mockBusinessesService.getMyBusinesses).toHaveBeenCalledWith(
      'usr-test-1',
      BusinessStatus.ACTIVE,
      'cursor',
      10,
    );
  });

  it('delegates getBusinesses to service', async () => {
    const query = { query: 'bakery', category: BusinessCategory.FOOD_DINING };
    await controller.getBusinesses(mockUser, query);
    expect(mockBusinessesService.getBusinesses).toHaveBeenCalledWith('usr-test-1', query);
  });

  it('delegates createBusiness to service', async () => {
    const dto = {
      name: 'Cafe Nero',
      category: BusinessCategory.FOOD_DINING,
      description: 'Cozy coffee shop with fresh pastries.',
    };
    await controller.createBusiness(mockUser, dto);
    expect(mockBusinessesService.createBusiness).toHaveBeenCalledWith('usr-test-1', dto);
  });

  it('delegates getBusinessById to service', async () => {
    await controller.getBusinessById('biz-1', mockUser);
    expect(mockBusinessesService.getBusinessById).toHaveBeenCalledWith('biz-1', 'usr-test-1');
  });

  it('delegates updateBusiness to service', async () => {
    const dto = { name: 'Cafe Nero & Roastery' };
    await controller.updateBusiness('biz-1', mockUser, dto);
    expect(mockBusinessesService.updateBusiness).toHaveBeenCalledWith('biz-1', 'usr-test-1', dto);
  });

  it('delegates updateBusinessStatus to service', async () => {
    const dto = { status: BusinessStatus.INACTIVE };
    await controller.updateBusinessStatus('biz-1', mockUser, dto);
    expect(mockBusinessesService.updateBusinessStatus).toHaveBeenCalledWith('biz-1', 'usr-test-1', BusinessStatus.INACTIVE);
  });

  it('delegates deleteBusiness to service', async () => {
    await controller.deleteBusiness('biz-1', mockUser);
    expect(mockBusinessesService.deleteBusiness).toHaveBeenCalledWith('biz-1', 'usr-test-1');
  });

  it('delegates favoriteBusiness and unfavoriteBusiness to service', async () => {
    await controller.favoriteBusiness('biz-1', mockUser);
    expect(mockBusinessesService.toggleFavorite).toHaveBeenCalledWith('biz-1', 'usr-test-1', true);

    await controller.unfavoriteBusiness('biz-1', mockUser);
    expect(mockBusinessesService.toggleFavorite).toHaveBeenCalledWith('biz-1', 'usr-test-1', false);
  });

  it('delegates reportBusiness to service', async () => {
    const dto = { reason: BusinessReportReason.SPAM, details: 'Duplicate listing' };
    await controller.reportBusiness('biz-1', mockUser, dto);
    expect(mockBusinessesService.reportBusiness).toHaveBeenCalledWith('biz-1', 'usr-test-1', dto);
  });
});

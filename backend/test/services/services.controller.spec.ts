import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ServicesController } from '../../src/modules/services/services.controller.js';
import { ServiceCategory, ServiceStatus } from '../../src/modules/services/entities/service-listing.entity.js';
import { ServiceReportReason } from '../../src/modules/services/entities/service-report.entity.js';

describe('ServicesController', () => {
  let controller: ServicesController;
  let mockServicesService: any;

  const mockUser = {
    userId: 'usr-test-1',
    phoneNumber: '+919999900001',
    onboardingCompleted: true,
  };

  beforeEach(() => {
    mockServicesService = {
      getCategories: vi.fn(() => []),
      getMyServices: vi.fn(async () => ({ items: [], nextCursor: null, hasMore: false })),
      getServices: vi.fn(async () => ({ items: [], nextCursor: null, hasMore: false })),
      createService: vi.fn(async (userId, dto) => ({ id: 'svc-1', ...dto, ownerId: userId })),
      getServiceById: vi.fn(async (id, userId) => ({ id, ownerId: userId })),
      updateService: vi.fn(async (id, userId, dto) => ({ id, ...dto, ownerId: userId })),
      updateServiceStatus: vi.fn(async (id, userId, status) => ({ id, status, ownerId: userId })),
      deleteService: vi.fn(async (id, userId) => ({ success: true, message: 'Deleted' })),
      toggleFavorite: vi.fn(async (id, userId, fav) => ({ isFavorited: fav, favoriteCount: 1 })),
      reportService: vi.fn(async (id, userId, dto) => ({ success: true, message: 'Reported' })),
    };

    controller = new ServicesController(mockServicesService);
  });

  it('delegates getCategories to service', () => {
    controller.getCategories();
    expect(mockServicesService.getCategories).toHaveBeenCalled();
  });

  it('delegates getMyServices to service', async () => {
    await controller.getMyServices(mockUser, ServiceStatus.ACTIVE, 'cursor', 10);
    expect(mockServicesService.getMyServices).toHaveBeenCalledWith(
      'usr-test-1',
      ServiceStatus.ACTIVE,
      'cursor',
      10,
    );
  });

  it('delegates getServices to service', async () => {
    const query = { query: 'plumber', category: ServiceCategory.HOME_REPAIR };
    await controller.getServices(mockUser, query);
    expect(mockServicesService.getServices).toHaveBeenCalledWith('usr-test-1', query);
  });

  it('delegates createService to service', async () => {
    const dto = {
      title: 'Plumber',
      category: ServiceCategory.HOME_REPAIR,
      description: 'Plumbing services.',
    };
    await controller.createService(mockUser, dto);
    expect(mockServicesService.createService).toHaveBeenCalledWith('usr-test-1', dto);
  });

  it('delegates getServiceById to service', async () => {
    await controller.getServiceById('svc-1', mockUser);
    expect(mockServicesService.getServiceById).toHaveBeenCalledWith('svc-1', 'usr-test-1');
  });

  it('delegates updateService to service', async () => {
    const dto = { title: 'Master Plumber' };
    await controller.updateService('svc-1', mockUser, dto);
    expect(mockServicesService.updateService).toHaveBeenCalledWith('svc-1', 'usr-test-1', dto);
  });

  it('delegates updateServiceStatus to service', async () => {
    const dto = { status: ServiceStatus.INACTIVE };
    await controller.updateServiceStatus('svc-1', mockUser, dto);
    expect(mockServicesService.updateServiceStatus).toHaveBeenCalledWith('svc-1', 'usr-test-1', ServiceStatus.INACTIVE);
  });

  it('delegates deleteService to service', async () => {
    await controller.deleteService('svc-1', mockUser);
    expect(mockServicesService.deleteService).toHaveBeenCalledWith('svc-1', 'usr-test-1');
  });

  it('delegates favoriteService and unfavoriteService to service', async () => {
    await controller.favoriteService('svc-1', mockUser);
    expect(mockServicesService.toggleFavorite).toHaveBeenCalledWith('svc-1', 'usr-test-1', true);

    await controller.unfavoriteService('svc-1', mockUser);
    expect(mockServicesService.toggleFavorite).toHaveBeenCalledWith('svc-1', 'usr-test-1', false);
  });

  it('delegates reportService to service', async () => {
    const dto = { reason: ServiceReportReason.SPAM, details: 'Duplicate listing' };
    await controller.reportService('svc-1', mockUser, dto);
    expect(mockServicesService.reportService).toHaveBeenCalledWith('svc-1', 'usr-test-1', dto);
  });
});

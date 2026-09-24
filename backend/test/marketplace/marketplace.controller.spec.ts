import { describe, it, expect, beforeEach, vi } from 'vitest';
import { MarketplaceController } from '../../src/modules/marketplace/marketplace.controller.js';
import {
  MarketplaceCategory,
  MarketplaceCondition,
  MarketplaceListingStatus,
} from '../../src/modules/marketplace/entities/marketplace-listing.entity.js';
import { MarketplaceReportReason } from '../../src/modules/marketplace/entities/marketplace-report.entity.js';

describe('MarketplaceController', () => {
  let controller: MarketplaceController;
  let mockService: any;

  const mockUserPayload = {
    userId: 'usr-123',
    phoneNumber: '+919999900001',
    sessionId: 'sess-123',
  };

  beforeEach(() => {
    mockService = {
      getListings: vi.fn(async () => ({ items: [], nextCursor: null, hasMore: false })),
      createListing: vi.fn(async (_, dto) => ({ id: 'lst-1', ...dto })),
      getMyListings: vi.fn(async () => ({ items: [], nextCursor: null, hasMore: false })),
      getListingById: vi.fn(async (id) => ({ id, title: 'Item' })),
      updateListing: vi.fn(async (id, _, dto) => ({ id, ...dto })),
      updateListingStatus: vi.fn(async (id, _, status) => ({ id, status })),
      deleteListing: vi.fn(async () => ({ message: 'Listing deleted successfully.' })),
      toggleFavorite: vi.fn(async () => ({ isFavorited: true, favoriteCount: 5 })),
      reportListing: vi.fn(async () => ({ message: 'Report submitted.' })),
    };

    controller = new MarketplaceController(mockService);
  });

  it('delegates getListings to service', async () => {
    const query = { category: MarketplaceCategory.ELECTRONICS, limit: 10 };
    await controller.getListings(mockUserPayload, query as any);
    expect(mockService.getListings).toHaveBeenCalledWith('usr-123', query);
  });

  it('delegates createListing to service with user context', async () => {
    const dto = {
      title: 'Gaming Laptop',
      description: 'High performance gaming laptop in pristine condition.',
      category: MarketplaceCategory.COMPUTERS,
      price: 65000,
      condition: MarketplaceCondition.LIKE_NEW,
    };
    await controller.createListing(mockUserPayload, dto as any);
    expect(mockService.createListing).toHaveBeenCalledWith('usr-123', dto);
  });

  it('delegates getMyListings to service', async () => {
    await controller.getMyListings(mockUserPayload, MarketplaceListingStatus.ACTIVE);
    expect(mockService.getMyListings).toHaveBeenCalledWith('usr-123', MarketplaceListingStatus.ACTIVE, undefined, 20);
  });

  it('delegates getListingById to service', async () => {
    await controller.getListingById('lst-1', mockUserPayload);
    expect(mockService.getListingById).toHaveBeenCalledWith('lst-1', 'usr-123');
  });

  it('delegates updateListing to service', async () => {
    const dto = { title: 'Updated Title' };
    await controller.updateListing('lst-1', mockUserPayload, dto as any);
    expect(mockService.updateListing).toHaveBeenCalledWith('lst-1', 'usr-123', dto);
  });

  it('delegates updateListingStatus to service', async () => {
    await controller.updateListingStatus('lst-1', mockUserPayload, { status: MarketplaceListingStatus.SOLD });
    expect(mockService.updateListingStatus).toHaveBeenCalledWith('lst-1', 'usr-123', MarketplaceListingStatus.SOLD);
  });

  it('delegates deleteListing to service', async () => {
    await controller.deleteListing('lst-1', mockUserPayload);
    expect(mockService.deleteListing).toHaveBeenCalledWith('lst-1', 'usr-123');
  });

  it('delegates favorite and unfavorite to service', async () => {
    await controller.favoriteListing('lst-1', mockUserPayload);
    expect(mockService.toggleFavorite).toHaveBeenCalledWith('lst-1', 'usr-123', true);

    await controller.unfavoriteListing('lst-1', mockUserPayload);
    expect(mockService.toggleFavorite).toHaveBeenCalledWith('lst-1', 'usr-123', false);
  });

  it('delegates reportListing to service', async () => {
    const dto = { reason: MarketplaceReportReason.SPAM, details: 'Spam listing' };
    await controller.reportListing('lst-1', mockUserPayload, dto);
    expect(mockService.reportListing).toHaveBeenCalledWith('lst-1', 'usr-123', dto);
  });
});

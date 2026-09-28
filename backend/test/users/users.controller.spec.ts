import { describe, it, expect, beforeEach, vi } from 'vitest';
import { UsersController } from '../../src/modules/users/users.controller.js';
import { UsersService } from '../../src/modules/users/users.service.js';
import { CurrentUserPayload } from '../../src/modules/auth/decorators/current-user.decorator.js';

describe('UsersController', () => {
  let controller: UsersController;
  let mockService: any;

  const mockUser: CurrentUserPayload = {
    userId: 'usr-123',
    sessionId: 'session-123',
    phoneNumber: '+919876543210',
    onboarding: true,
  };

  const sampleProfile = {
    id: 'usr-123',
    username: 'sujeet',
    phoneNumber: '+91 ••••••3210',
    displayName: 'Sujeet Sharma',
    avatarUrl: 'https://example.com/avatar.jpg',
    bio: 'Resident in Sector 52',
    phoneVerified: true,
    accountStatus: 'active',
    role: 'user',
    onboardingCompleted: true,
    locality: {
      countryCode: 'IN',
      state: 'Uttar Pradesh',
      district: 'Gautam Buddha Nagar',
      city: 'Noida',
      locality: 'Sector 52',
      neighborhood: 'Antriksh Golf View',
    },
    lastLoginAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(() => {
    mockService = {
      getProfile: vi.fn().mockResolvedValue(sampleProfile),
      checkUsernameAvailability: vi.fn().mockResolvedValue({
        username: 'sujeet',
        available: true,
      }),
      updateUsername: vi.fn().mockResolvedValue({
        ...sampleProfile,
        username: 'sujeet_new',
      }),
      getUserByUsername: vi.fn().mockResolvedValue({
        id: 'usr-123',
        username: 'sujeet',
        displayName: 'Sujeet Sharma',
        avatarUrl: 'https://example.com/avatar.jpg',
      }),
      searchUsers: vi.fn().mockResolvedValue({
        items: [
          {
            id: 'usr-123',
            username: 'sujeet',
            displayName: 'Sujeet Sharma',
          },
        ],
        total: 1,
        page: 1,
        limit: 20,
      }),
      updateProfile: vi.fn().mockResolvedValue({
        ...sampleProfile,
        displayName: 'Sujeet Updated',
        bio: 'Updated bio',
      }),
      completeOnboarding: vi.fn().mockResolvedValue(sampleProfile),
    };

    controller = new UsersController(mockService as UsersService);
  });

  it('retrieves user profile for authenticated user', async () => {
    const profile = await controller.getProfile(mockUser);
    expect(mockService.getProfile).toHaveBeenCalledWith('usr-123');
    expect(profile.displayName).toBe('Sujeet Sharma');
    expect(profile.username).toBe('sujeet');
  });

  it('checks username availability via GET /users/check-username', async () => {
    const res = await controller.checkUsername('sujeet', mockUser);
    expect(mockService.checkUsernameAvailability).toHaveBeenCalledWith('sujeet', 'usr-123');
    expect(res.available).toBe(true);
  });

  it('updates username via PATCH /users/me/username', async () => {
    const res = await controller.updateUsername(mockUser, { username: 'sujeet_new' });
    expect(mockService.updateUsername).toHaveBeenCalledWith('usr-123', 'sujeet_new');
    expect(res.username).toBe('sujeet_new');
  });

  it('searches users via GET /users/search', async () => {
    const res = await controller.searchUsers({ q: 'sujeet', limit: 20, page: 1 });
    expect(mockService.searchUsers).toHaveBeenCalledWith('sujeet', 20, 1);
    expect(res.total).toBe(1);
    expect(res.items[0].username).toBe('sujeet');
  });

  it('retrieves public profile by username via GET /users/username/:username', async () => {
    const res = await controller.getUserByUsername('sujeet');
    expect(mockService.getUserByUsername).toHaveBeenCalledWith('sujeet');
    expect(res.username).toBe('sujeet');
    expect(res.displayName).toBe('Sujeet Sharma');
  });

  it('updates user profile via PATCH /users/me/profile', async () => {
    const dto = {
      displayName: 'Sujeet Updated',
      bio: 'Updated bio',
    };
    const updated = await controller.updateProfile(mockUser, dto);
    expect(mockService.updateProfile).toHaveBeenCalledWith('usr-123', dto);
    expect(updated.displayName).toBe('Sujeet Updated');
    expect(updated.bio).toBe('Updated bio');
  });

  it('completes onboarding via PATCH /users/me/onboarding', async () => {
    const dto = {
      displayName: 'Sujeet Sharma',
      city: 'Noida',
      locality: 'Sector 52',
    };
    const res = await controller.completeOnboarding(mockUser, dto);
    expect(mockService.completeOnboarding).toHaveBeenCalledWith('usr-123', dto);
    expect(res.onboardingCompleted).toBe(true);
  });
});

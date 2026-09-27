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
    expect(profile.bio).toBe('Resident in Sector 52');
    expect(profile.phoneVerified).toBe(true);
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

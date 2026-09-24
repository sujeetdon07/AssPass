import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Repository } from 'typeorm';
import { UsersService } from '../../src/modules/users/users.service.js';
import { User, UserStatus } from '../../src/modules/users/entities/user.entity.js';

describe('UsersService', () => {
  let usersService: UsersService;
  let mockUserRepo: Partial<Repository<User>>;

  beforeEach(() => {
    mockUserRepo = {
      findOne: vi.fn(),
      save: vi.fn(async (u) => u as User),
    };

    usersService = new UsersService(mockUserRepo as Repository<User>);
  });

  it('completes onboarding by updating displayName, locality, and setting onboardingCompleted=true', async () => {
    const existingUser: Partial<User> = {
      id: 'usr-123',
      phoneNumber: '+919876543210',
      displayName: null,
      onboardingCompleted: false,
      accountStatus: UserStatus.ACTIVE,
    };

    mockUserRepo.findOne = vi.fn().mockResolvedValue(existingUser);

    const result = await usersService.completeOnboarding('usr-123', {
      displayName: 'Sujeet Sharma',
      city: 'Bengaluru',
      locality: 'Indiranagar',
      state: 'Karnataka',
      countryCode: 'IN',
      neighborhood: 'Defence Colony',
    });

    expect(result.displayName).toBe('Sujeet Sharma');
    expect(result.onboardingCompleted).toBe(true);
    expect(result.locality.city).toBe('Bengaluru');
    expect(result.locality.locality).toBe('Indiranagar');
    expect(result.phoneNumber).toBe('+91 ••••••3210');
  });

  it('throws NotFoundException when user does not exist', async () => {
    mockUserRepo.findOne = vi.fn().mockResolvedValue(null);

    await expect(
      usersService.completeOnboarding('non-existent-id', {
        displayName: 'Test User',
      }),
    ).rejects.toThrow();
  });
});

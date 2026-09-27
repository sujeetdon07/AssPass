import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Repository } from 'typeorm';
import { UsersService } from '../../src/modules/users/users.service.js';
import { User, UserStatus, UserRole } from '../../src/modules/users/entities/user.entity.js';

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
      role: UserRole.USER,
      createdAt: new Date(),
      updatedAt: new Date(),
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

  it('retrieves user profile with bio and verification info', async () => {
    const existingUser: Partial<User> = {
      id: 'usr-123',
      phoneNumber: '+919876543210',
      displayName: 'Sujeet Sharma',
      bio: 'Neighbor in Sector 52',
      phoneVerified: true,
      onboardingCompleted: true,
      accountStatus: UserStatus.ACTIVE,
      role: UserRole.USER,
      city: 'Noida',
      locality: 'Sector 52',
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    mockUserRepo.findOne = vi.fn().mockResolvedValue(existingUser);

    const profile = await usersService.getProfile('usr-123');
    expect(profile.displayName).toBe('Sujeet Sharma');
    expect(profile.bio).toBe('Neighbor in Sector 52');
    expect(profile.phoneVerified).toBe(true);
    expect(profile.locality.city).toBe('Noida');
  });

  it('updates profile fields including bio, avatar, and locality', async () => {
    const existingUser: Partial<User> = {
      id: 'usr-123',
      phoneNumber: '+919876543210',
      displayName: 'Sujeet',
      bio: null,
      avatarUrl: null,
      onboardingCompleted: true,
      accountStatus: UserStatus.ACTIVE,
      role: UserRole.USER,
      city: 'Noida',
      locality: 'Sector 52',
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    mockUserRepo.findOne = vi.fn().mockResolvedValue(existingUser);

    const updated = await usersService.updateProfile('usr-123', {
      displayName: 'Sujeet Sharma',
      bio: 'Avid badminton player and resident of Antriksh Golf View',
      avatarUrl: 'https://example.com/avatar.jpg',
      locality: 'Sector 52',
      city: 'Noida',
      neighborhood: 'Antriksh Golf View',
    });

    expect(updated.displayName).toBe('Sujeet Sharma');
    expect(updated.bio).toBe('Avid badminton player and resident of Antriksh Golf View');
    expect(updated.avatarUrl).toBe('https://example.com/avatar.jpg');
    expect(updated.locality.neighborhood).toBe('Antriksh Golf View');
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

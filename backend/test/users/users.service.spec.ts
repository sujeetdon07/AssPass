import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Repository } from 'typeorm';
import { UsersService } from '../../src/modules/users/users.service.js';
import { User, UserStatus, UserRole } from '../../src/modules/users/entities/user.entity.js';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { UsernameValidator } from '../../src/modules/users/utils/username.validator.js';

describe('UsersService', () => {
  let usersService: UsersService;
  let mockUserRepo: Partial<Repository<User>>;

  beforeEach(() => {
    mockUserRepo = {
      findOne: vi.fn(),
      save: vi.fn(async (u) => u as User),
      createQueryBuilder: vi.fn(),
    };

    usersService = new UsersService(mockUserRepo as Repository<User>);
  });

  describe('Onboarding & Profile basics', () => {
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

    it('retrieves user profile with bio, verification info, and username', async () => {
      const existingUser: Partial<User> = {
        id: 'usr-123',
        username: 'sujeet',
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
      expect(profile.username).toBe('sujeet');
      expect(profile.displayName).toBe('Sujeet Sharma');
      expect(profile.bio).toBe('Neighbor in Sector 52');
      expect(profile.phoneVerified).toBe(true);
      expect(profile.locality.city).toBe('Noida');
    });

    it('works seamlessly for existing user without username (nullable backward compatibility)', async () => {
      const existingUser: Partial<User> = {
        id: 'usr-old',
        username: null,
        phoneNumber: '+919876543210',
        displayName: 'Old Neighbor',
        phoneVerified: true,
        onboardingCompleted: true,
        accountStatus: UserStatus.ACTIVE,
        role: UserRole.USER,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockUserRepo.findOne = vi.fn().mockResolvedValue(existingUser);

      const profile = await usersService.getProfile('usr-old');
      expect(profile.username).toBeNull();
      expect(profile.displayName).toBe('Old Neighbor');
    });
  });

  describe('Username validation rules', () => {
    it('accepts valid usernames with letters, numbers, and underscores', () => {
      expect(UsernameValidator.validate('sujeet').isValid).toBe(true);
      expect(UsernameValidator.validate('sujeet123').isValid).toBe(true);
      expect(UsernameValidator.validate('sujeet_kumar').isValid).toBe(true);
      expect(UsernameValidator.validate('@sujeet_99').isValid).toBe(true);
      expect(UsernameValidator.validate('@sujeet_99').normalized).toBe('sujeet_99');
    });

    it('rejects usernames that are too short (< 3 chars)', () => {
      const res = UsernameValidator.validate('su');
      expect(res.isValid).toBe(false);
      expect(res.error).toContain('at least 3 characters');
    });

    it('rejects usernames that are too long (> 30 chars)', () => {
      const res = UsernameValidator.validate('a'.repeat(31));
      expect(res.isValid).toBe(false);
      expect(res.error).toContain('cannot exceed 30 characters');
    });

    it('rejects invalid characters, spaces, and punctuation', () => {
      expect(UsernameValidator.validate('sujeet kumar').isValid).toBe(false);
      expect(UsernameValidator.validate('sujeet.kumar').isValid).toBe(false);
      expect(UsernameValidator.validate('sujeet-kumar').isValid).toBe(false);
      expect(UsernameValidator.validate('sujeet!').isValid).toBe(false);
    });

    it('rejects reserved system usernames', () => {
      expect(UsernameValidator.validate('admin').isValid).toBe(false);
      expect(UsernameValidator.validate('ADMIN').isValid).toBe(false);
      expect(UsernameValidator.validate('support').isValid).toBe(false);
      expect(UsernameValidator.validate('aaspaas').isValid).toBe(false);
      expect(UsernameValidator.validate('marketplace').isValid).toBe(false);
    });
  });

  describe('Username Availability Check', () => {
    it('returns available: true for an unreserved, unused valid username', async () => {
      mockUserRepo.findOne = vi.fn().mockResolvedValue(null);

      const res = await usersService.checkUsernameAvailability('unique_user_99');
      expect(res.available).toBe(true);
      expect(res.username).toBe('unique_user_99');
    });

    it('returns available: false for an invalid username', async () => {
      const res = await usersService.checkUsernameAvailability('no');
      expect(res.available).toBe(false);
      expect(res.message).toBeDefined();
    });

    it('returns available: false for a reserved username', async () => {
      const res = await usersService.checkUsernameAvailability('admin');
      expect(res.available).toBe(false);
      expect(res.message).toContain('reserved');
    });

    it('returns available: false for case-insensitive duplicate username taken by another user', async () => {
      mockUserRepo.findOne = vi.fn().mockResolvedValue({
        id: 'usr-other',
        username: 'sujeet',
      });

      const res = await usersService.checkUsernameAvailability('SUJEET', 'usr-my-id');
      expect(res.available).toBe(false);
      expect(res.message).toContain('already taken');
    });

    it('returns available: true when the requesting user already owns the username', async () => {
      mockUserRepo.findOne = vi.fn().mockResolvedValue({
        id: 'usr-my-id',
        username: 'sujeet',
      });

      const res = await usersService.checkUsernameAvailability('sujeet', 'usr-my-id');
      expect(res.available).toBe(true);
      expect(res.message).toContain('already own');
    });
  });

  describe('Username Update & Lookup', () => {
    it('successfully updates username to normalized lowercase and preserves User ID', async () => {
      const existingUser: Partial<User> = {
        id: 'usr-123',
        username: 'old_handle',
        displayName: 'Sujeet',
        phoneNumber: '+919876543210',
        accountStatus: UserStatus.ACTIVE,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockUserRepo.findOne = vi
        .fn()
        // First call for findById('usr-123')
        .mockResolvedValueOnce(existingUser)
        // Second call for findByUsername('new_handle') check
        .mockResolvedValueOnce(null);

      const updated = await usersService.updateUsername('usr-123', '@New_Handle');

      expect(updated.id).toBe('usr-123'); // Internal immutable ID preserved!
      expect(updated.username).toBe('new_handle');
      expect(existingUser.username).toBe('new_handle');
    });

    it('rejects duplicate username change when taken by another user', async () => {
      const existingUser: Partial<User> = {
        id: 'usr-123',
        username: 'sujeet_1',
      };
      const takenUser: Partial<User> = {
        id: 'usr-999',
        username: 'sujeet_2',
      };

      mockUserRepo.findOne = vi
        .fn()
        .mockResolvedValueOnce(existingUser)
        .mockResolvedValueOnce(takenUser);

      await expect(
        usersService.updateUsername('usr-123', 'sujeet_2'),
      ).rejects.toThrow(ConflictException);
    });

    it('throws BadRequestException when updating with an invalid username', async () => {
      mockUserRepo.findOne = vi.fn().mockResolvedValue({ id: 'usr-123' });

      await expect(
        usersService.updateUsername('usr-123', 'bad username with spaces'),
      ).rejects.toThrow(BadRequestException);
    });

    it('resolves public user profile by username without exposing phone number', async () => {
      const user: Partial<User> = {
        id: 'usr-123',
        username: 'sujeet',
        displayName: 'Sujeet Sharma',
        avatarUrl: 'https://example.com/avatar.jpg',
        bio: 'Hello Aaspaas',
        phoneNumber: '+919876543210',
        accountStatus: UserStatus.ACTIVE,
        phoneVerified: true,
        city: 'Bengaluru',
        locality: 'Koramangala',
        createdAt: new Date(),
      };

      mockUserRepo.findOne = vi.fn().mockResolvedValue(user);

      const result = await usersService.getUserByUsername('@Sujeet');
      expect(result.id).toBe('usr-123');
      expect(result.username).toBe('sujeet');
      expect(result.displayName).toBe('Sujeet Sharma');
      expect((result as any).phoneNumber).toBeUndefined(); // Strict privacy protection
    });

    it('throws NotFoundException when looking up non-existent username', async () => {
      mockUserRepo.findOne = vi.fn().mockResolvedValue(null);

      await expect(
        usersService.getUserByUsername('does_not_exist'),
      ).rejects.toThrow(NotFoundException);
    });

    it('handles database race condition (23505 unique constraint violation) on concurrent save', async () => {
      const existingUser: Partial<User> = {
        id: 'usr-123',
        username: 'sujeet_old',
      };

      mockUserRepo.findOne = vi
        .fn()
        .mockResolvedValueOnce(existingUser) // findById
        .mockResolvedValueOnce(null); // findByUsername check passes initially

      const dbConflictError: any = new Error('duplicate key value violates unique constraint');
      dbConflictError.code = '23505';
      mockUserRepo.save = vi.fn().mockRejectedValueOnce(dbConflictError);

      await expect(
        usersService.updateUsername('usr-123', 'sujeet_concurrent'),
      ).rejects.toThrow(ConflictException);
    });

    it('preserves conversation integrity because internal User ID remains permanent and unchanged', async () => {
      const existingUser: Partial<User> = {
        id: 'usr-permanent-uuid-999',
        username: 'sujeet_initial',
        displayName: 'Sujeet Kumar',
        phoneNumber: '+919876543210',
        accountStatus: UserStatus.ACTIVE,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockUserRepo.findOne = vi
        .fn()
        .mockResolvedValueOnce(existingUser)
        .mockResolvedValueOnce(null);

      const updated = await usersService.updateUsername(
        'usr-permanent-uuid-999',
        'sujeet_updated',
      );

      // Identity invariant check
      expect(updated.id).toBe('usr-permanent-uuid-999');
      expect(updated.username).toBe('sujeet_updated');

      // Conversations link via user ID, which never changed
      const conversationMock = {
        id: 'conv-abc',
        participantId: updated.id,
      };
      expect(conversationMock.participantId).toBe('usr-permanent-uuid-999');
    });
  });

  describe('User Search', () => {
    it('searches users by query and maps results cleanly without phone numbers', async () => {
      const mockQueryBuilder = {
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        addOrderBy: vi.fn().mockReturnThis(),
        setParameters: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        skip: vi.fn().mockReturnThis(),
        getManyAndCount: vi.fn().mockResolvedValue([
          [
            {
              id: 'usr-1',
              username: 'sujeet',
              displayName: 'Sujeet Kumar',
              avatarUrl: 'https://example.com/sujeet.webp',
              phoneNumber: '+919876543210',
              bio: 'Active resident',
              locality: 'Indiranagar',
              city: 'Bengaluru',
            },
          ],
          1,
        ]),
      };

      mockUserRepo.createQueryBuilder = vi.fn().mockReturnValue(mockQueryBuilder);

      const res = await usersService.searchUsers('@sujeet', 20, 1);

      expect(res.total).toBe(1);
      expect(res.items.length).toBe(1);
      expect(res.items[0].username).toBe('sujeet');
      expect(res.items[0].displayName).toBe('Sujeet Kumar');
      expect((res.items[0] as any).phoneNumber).toBeUndefined();
    });

    it('returns empty result when search query is empty', async () => {
      const res = await usersService.searchUsers('', 20, 1);
      expect(res.items).toEqual([]);
      expect(res.total).toBe(0);
    });
  });
});

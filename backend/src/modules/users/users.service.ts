import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Raw } from 'typeorm';
import { User, UserStatus } from './entities/user.entity.js';
import { CompleteOnboardingDto } from './dto/complete-onboarding.dto.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
import { PhoneNumberUtil } from '../auth/utils/phone-number.util.js';
import { RedisService } from '../../database/redis.service.js';
import { UsernameValidator } from './utils/username.validator.js';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly redisService?: RedisService,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.userRepository.findOne({ where: { id } });
  }

  async findByPhone(phoneNumber: string): Promise<User | null> {
    return this.userRepository.findOne({ where: { phoneNumber } });
  }

  /**
   * Find a user by case-insensitive unique username.
   */
  async findByUsername(rawUsername: string): Promise<User | null> {
    const normalized = UsernameValidator.normalize(rawUsername);
    if (!normalized) return null;

    return this.userRepository.findOne({
      where: {
        username: Raw((alias) => `LOWER(${alias}) = LOWER(:username)`, {
          username: normalized,
        }),
      },
    });
  }

  /**
   * Check whether a requested username is available, reserved, invalid, or already taken.
   */
  async checkUsernameAvailability(
    rawUsername: string,
    currentUserId?: string,
  ): Promise<{ username: string; available: boolean; message?: string }> {
    const validation = UsernameValidator.validate(rawUsername);
    if (!validation.isValid) {
      return {
        username: validation.normalized,
        available: false,
        message: validation.error,
      };
    }

    const existingUser = await this.findByUsername(validation.normalized);
    if (existingUser) {
      if (currentUserId && existingUser.id === currentUserId) {
        return {
          username: validation.normalized,
          available: true,
          message: 'You already own this username.',
        };
      }
      return {
        username: validation.normalized,
        available: false,
        message: 'This username is already taken.',
      };
    }

    return {
      username: validation.normalized,
      available: true,
    };
  }

  /**
   * Formats a user entity into public profile payload.
   */
  formatUserProfile(user: User) {
    return {
      id: user.id,
      username: user.username ?? null,
      phoneNumber: PhoneNumberUtil.mask(user.phoneNumber),
      displayName: user.displayName,
      avatarUrl: user.avatarUrl ?? null,
      bio: user.bio ?? null,
      phoneVerified: user.phoneVerified ?? true,
      accountStatus: user.accountStatus,
      role: user.role,
      onboardingCompleted: user.onboardingCompleted,
      locality: {
        countryCode: user.countryCode ?? 'IN',
        state: user.state ?? null,
        district: user.district ?? null,
        city: user.city ?? null,
        locality: user.locality ?? null,
        neighborhood: user.neighborhood ?? null,
      },
      lastLoginAt: user.lastLoginAt ?? null,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }

  /**
   * Retrieves profile of authenticated user.
   */
  async getProfile(userId: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found.');
    }
    return this.formatUserProfile(user);
  }

  /**
   * Public profile resolution by unique @username.
   * Strips all private information such as phone number.
   */
  async getUserByUsername(rawUsername: string) {
    const normalized = UsernameValidator.normalize(rawUsername);
    if (!normalized) {
      throw new BadRequestException('Invalid username.');
    }

    const user = await this.findByUsername(normalized);
    if (!user || user.accountStatus === UserStatus.DELETED) {
      throw new NotFoundException(`User with username @${normalized} not found.`);
    }

    return {
      id: user.id,
      username: user.username,
      displayName: user.displayName ?? 'Neighbor',
      avatarUrl: user.avatarUrl ?? null,
      bio: user.bio ?? null,
      accountStatus: user.accountStatus,
      phoneVerified: user.phoneVerified ?? true,
      locality: {
        countryCode: user.countryCode ?? 'IN',
        state: user.state ?? null,
        district: user.district ?? null,
        city: user.city ?? null,
        locality: user.locality ?? null,
        neighborhood: user.neighborhood ?? null,
      },
      createdAt: user.createdAt,
    };
  }

  /**
   * Update authenticated user's unique username.
   */
  async updateUsername(userId: string, rawUsername: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found.');
    }

    const validation = UsernameValidator.validate(rawUsername);
    if (!validation.isValid) {
      throw new BadRequestException(validation.error);
    }

    // Check availability against other accounts
    const existing = await this.findByUsername(validation.normalized);
    if (existing && existing.id !== userId) {
      throw new ConflictException('This username is already taken.');
    }

    user.username = validation.normalized;
    try {
      const updatedUser = await this.userRepository.save(user);
      this.logger.log(`User ${user.id} changed username to @${validation.normalized}.`);
      return this.formatUserProfile(updatedUser);
    } catch (err: any) {
      if (err?.code === '23505' || err?.driverError?.code === '23505') {
        throw new ConflictException('This username is already taken.');
      }
      throw err;
    }
  }

  /**
   * Search users by username (with or without @) or display name.
   * Results never expose phone numbers.
   */
  async searchUsers(query: string, limit: number = 20, page: number = 1) {
    const cleaned = UsernameValidator.normalize(query);
    if (!cleaned) {
      return {
        items: [],
        total: 0,
        page,
        limit,
      };
    }

    const likeTerm = `%${cleaned}%`;
    const exactTerm = cleaned;
    const prefixTerm = `${cleaned}%`;

    const qb = this.userRepository
      .createQueryBuilder('user')
      .where('user.accountStatus = :active', { active: UserStatus.ACTIVE })
      .andWhere(
        '(LOWER(user.username) LIKE :likeTerm OR LOWER(user.displayName) LIKE :likeTerm)',
        { likeTerm },
      )
      .orderBy(
        `CASE
          WHEN LOWER(user.username) = :exactTerm THEN 0
          WHEN LOWER(user.username) LIKE :prefixTerm THEN 1
          WHEN LOWER(user.displayName) LIKE :prefixTerm THEN 2
          ELSE 3
        END`,
        'ASC',
      )
      .addOrderBy('user.displayName', 'ASC')
      .setParameters({ exactTerm, prefixTerm })
      .take(limit)
      .skip((page - 1) * limit);

    const [users, total] = await qb.getManyAndCount();

    const items = users.map((u) => ({
      id: u.id,
      username: u.username ?? null,
      displayName: u.displayName ?? 'Neighbor',
      avatarUrl: u.avatarUrl ?? null,
      bio: u.bio ?? null,
      locality: u.locality ?? null,
      city: u.city ?? null,
    }));

    return {
      items,
      total,
      page,
      limit,
    };
  }

  /**
   * Update profile fields (display name, bio, avatar, locality, username).
   */
  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found.');
    }

    if (dto.username !== undefined) {
      const trimmed = dto.username.trim();
      if (trimmed.length > 0) {
        const validation = UsernameValidator.validate(trimmed);
        if (!validation.isValid) {
          throw new BadRequestException(validation.error);
        }
        const existing = await this.findByUsername(validation.normalized);
        if (existing && existing.id !== userId) {
          throw new ConflictException('This username is already taken.');
        }
        user.username = validation.normalized;
      }
    }

    if (dto.displayName !== undefined) {
      user.displayName = dto.displayName.trim();
    }
    if (dto.bio !== undefined) {
      user.bio = dto.bio.trim();
    }
    if (dto.avatarUrl !== undefined) {
      user.avatarUrl = dto.avatarUrl.trim().length > 0 ? dto.avatarUrl.trim() : null;
    }
    if (dto.countryCode !== undefined) {
      user.countryCode = dto.countryCode.trim().toUpperCase();
    }
    if (dto.state !== undefined) {
      user.state = dto.state.trim();
    }
    if (dto.district !== undefined) {
      user.district = dto.district.trim();
    }
    if (dto.city !== undefined) {
      user.city = dto.city.trim();
    }
    if (dto.locality !== undefined) {
      user.locality = dto.locality.trim();
    }
    if (dto.neighborhood !== undefined) {
      user.neighborhood = dto.neighborhood.trim();
    }

    try {
      const updatedUser = await this.userRepository.save(user);

      try {
        await this.redisService?.del(`user:locality:${userId}`);
      } catch {}

      this.logger.log(`User ${user.id} updated profile details.`);
      return this.formatUserProfile(updatedUser);
    } catch (err: any) {
      if (err?.code === '23505' || err?.driverError?.code === '23505') {
        throw new ConflictException('This username is already taken.');
      }
      throw err;
    }
  }

  /**
   * Completes onboarding for the authenticated user by setting display name,
   * locality foundation, optional username, and marking onboardingCompleted = true.
   */
  async completeOnboarding(userId: string, dto: CompleteOnboardingDto) {
    const user = await this.userRepository.findOne({ where: { id: userId } });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    if (dto.username) {
      const validation = UsernameValidator.validate(dto.username);
      if (!validation.isValid) {
        throw new BadRequestException(validation.error);
      }
      const existing = await this.findByUsername(validation.normalized);
      if (existing && existing.id !== userId) {
        throw new ConflictException('This username is already taken.');
      }
      user.username = validation.normalized;
    }

    user.displayName = dto.displayName.trim();
    if (dto.countryCode) user.countryCode = dto.countryCode.trim().toUpperCase();
    if (dto.state) user.state = dto.state.trim();
    if (dto.district) user.district = dto.district.trim();
    if (dto.city) user.city = dto.city.trim();
    if (dto.locality) user.locality = dto.locality.trim();
    if (dto.neighborhood) user.neighborhood = dto.neighborhood.trim();
    if (dto.avatarUrl) user.avatarUrl = dto.avatarUrl.trim();

    user.onboardingCompleted = true;
    user.phoneVerified = true;

    try {
      const updatedUser = await this.userRepository.save(user);
      try {
        await this.redisService?.del(`user:locality:${userId}`);
      } catch {}
      this.logger.log(`User ${user.id} successfully completed onboarding.`);

      return this.formatUserProfile(updatedUser);
    } catch (err: any) {
      if (err?.code === '23505' || err?.driverError?.code === '23505') {
        throw new ConflictException('This username is already taken.');
      }
      throw err;
    }
  }
}

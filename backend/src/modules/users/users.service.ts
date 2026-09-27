import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity.js';
import { CompleteOnboardingDto } from './dto/complete-onboarding.dto.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
import { PhoneNumberUtil } from '../auth/utils/phone-number.util.js';
import { RedisService } from '../../database/redis.service.js';

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
   * Formats a user entity into public profile payload.
   */
  formatUserProfile(user: User) {
    return {
      id: user.id,
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
   * Update profile fields (display name, bio, avatar, locality, etc.).
   */
  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found.');
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

    const updatedUser = await this.userRepository.save(user);

    try {
      await this.redisService?.del(`user:locality:${userId}`);
    } catch {}

    this.logger.log(`User ${user.id} updated profile details.`);
    return this.formatUserProfile(updatedUser);
  }

  /**
   * Completes onboarding for the authenticated user by setting display name,
   * locality foundation, and marking onboardingCompleted = true.
   */
  async completeOnboarding(userId: string, dto: CompleteOnboardingDto) {
    const user = await this.userRepository.findOne({ where: { id: userId } });

    if (!user) {
      throw new NotFoundException('User not found.');
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

    const updatedUser = await this.userRepository.save(user);
    try {
      await this.redisService?.del(`user:locality:${userId}`);
    } catch {}
    this.logger.log(`User ${user.id} successfully completed onboarding.`);

    return this.formatUserProfile(updatedUser);
  }
}

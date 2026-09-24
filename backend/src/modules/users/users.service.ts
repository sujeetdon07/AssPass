import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity.js';
import { CompleteOnboardingDto } from './dto/complete-onboarding.dto.js';
import { PhoneNumberUtil } from '../auth/utils/phone-number.util.js';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.userRepository.findOne({ where: { id } });
  }

  async findByPhone(phoneNumber: string): Promise<User | null> {
    return this.userRepository.findOne({ where: { phoneNumber } });
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

    const updatedUser = await this.userRepository.save(user);
    this.logger.log(`User ${user.id} successfully completed onboarding.`);

    return {
      id: updatedUser.id,
      phoneNumber: PhoneNumberUtil.mask(updatedUser.phoneNumber),
      displayName: updatedUser.displayName,
      avatarUrl: updatedUser.avatarUrl ?? null,
      accountStatus: updatedUser.accountStatus,
      onboardingCompleted: updatedUser.onboardingCompleted,
      locality: {
        countryCode: updatedUser.countryCode ?? 'IN',
        state: updatedUser.state ?? null,
        district: updatedUser.district ?? null,
        city: updatedUser.city ?? null,
        locality: updatedUser.locality ?? null,
        neighborhood: updatedUser.neighborhood ?? null,
      },
      updatedAt: updatedUser.updatedAt,
    };
  }
}

import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User, UserStatus } from '../../users/entities/user.entity.js';
import { AuthSession } from '../entities/auth-session.entity.js';
import { OtpService, RequestOtpResult } from './otp.service.js';
import { TokenService } from './token.service.js';
import { PhoneNumberUtil } from '../utils/phone-number.util.js';
import { DeviceMetadataDto } from '../dto/verify-otp.dto.js';

export interface AuthResponse {
  user: {
    id: string;
    phoneNumber: string; // Masked
    displayName: string | null;
    avatarUrl: string | null;
    onboardingCompleted: boolean;
    accountStatus: UserStatus;
  };
  tokens: {
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
  };
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(AuthSession)
    private readonly sessionRepository: Repository<AuthSession>,
    private readonly otpService: OtpService,
    private readonly tokenService: TokenService,
  ) {}

  /**
   * Request an OTP for the given raw phone number.
   */
  async requestOtp(
    rawPhoneNumber: string,
  ): Promise<RequestOtpResult & { maskedPhoneNumber: string }> {
    let normalizedPhone: string;
    try {
      normalizedPhone = PhoneNumberUtil.normalize(rawPhoneNumber);
    } catch {
      throw new BadRequestException(
        'Please enter a valid mobile number (e.g. +91 98765 43210).',
      );
    }

    const maskedPhoneNumber = PhoneNumberUtil.mask(normalizedPhone);
    const result = await this.otpService.requestOtp(normalizedPhone);

    return {
      ...result,
      maskedPhoneNumber,
    };
  }

  /**
   * Verify an OTP and initiate an authenticated session.
   * Creates a new user record if this is the first login.
   */
  async verifyOtp(
    rawPhoneNumber: string,
    otp: string,
    deviceMetadata?: DeviceMetadataDto,
    ipAddress?: string,
    userAgent?: string,
  ): Promise<AuthResponse> {
    let normalizedPhone: string;
    try {
      normalizedPhone = PhoneNumberUtil.normalize(rawPhoneNumber);
    } catch {
      throw new BadRequestException('Please enter a valid mobile number.');
    }

    const verifyResult = await this.otpService.verifyOtp(normalizedPhone, otp);
    if (!verifyResult.isValid) {
      throw new BadRequestException(
        verifyResult.message ?? 'Invalid or expired verification code.',
      );
    }

    // Find or create User record
    let user = await this.userRepository.findOne({
      where: { phoneNumber: normalizedPhone },
    });

    if (!user) {
      user = this.userRepository.create({
        phoneNumber: normalizedPhone,
        accountStatus: UserStatus.ACTIVE,
        onboardingCompleted: false,
        countryCode: 'IN',
        lastLoginAt: new Date(),
      });
      user = await this.userRepository.save(user);
      this.logger.log(`Created new user with ID: ${user.id}`);
    } else {
      if (user.accountStatus !== UserStatus.ACTIVE) {
        throw new UnauthorizedException(
          'This account has been suspended or deactivated. Please contact support.',
        );
      }
      user.lastLoginAt = new Date();
      await this.userRepository.save(user);
    }

    // Format device information string
    let deviceInfoStr: string | null = null;
    if (deviceMetadata) {
      const parts = [
        deviceMetadata.model,
        deviceMetadata.platform,
        deviceMetadata.appVersion ? `v${deviceMetadata.appVersion}` : undefined,
      ].filter(Boolean);
      if (parts.length > 0) deviceInfoStr = parts.join(' • ');
    }
    if (!deviceInfoStr && userAgent) {
      deviceInfoStr = userAgent.slice(0, 255);
    }

    // Create session record in database
    const session = this.sessionRepository.create({
      userId: user.id,
      refreshTokenHash: 'pending', // Will update immediately after generating token
      deviceInfo: deviceInfoStr,
      ipAddress: ipAddress ?? null,
      expiresAt: this.tokenService.getRefreshTokenExpiryDate(),
      revokedAt: null,
    });

    const savedSession = await this.sessionRepository.save(session);

    // Generate JWT access and refresh token pair
    const tokens = this.tokenService.generateTokens({
      userId: user.id,
      sessionId: savedSession.id,
      phone: PhoneNumberUtil.mask(user.phoneNumber),
      onboarding: user.onboardingCompleted,
    });

    // Hash refresh token and store in session
    savedSession.refreshTokenHash = this.tokenService.hashRefreshToken(
      tokens.refreshToken,
    );
    await this.sessionRepository.save(savedSession);

    return {
      user: {
        id: user.id,
        phoneNumber: PhoneNumberUtil.mask(user.phoneNumber),
        displayName: user.displayName ?? null,
        avatarUrl: user.avatarUrl ?? null,
        onboardingCompleted: user.onboardingCompleted,
        accountStatus: user.accountStatus,
      },
      tokens,
    };
  }

  /**
   * Rotate credentials using a valid refresh token.
   */
  async refreshTokens(refreshToken: string): Promise<{
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
  }> {
    let payload;
    try {
      payload = this.tokenService.verifyRefreshToken(refreshToken);
    } catch {
      throw new UnauthorizedException('Refresh token is invalid or expired. Please log in again.');
    }

    const session = await this.sessionRepository.findOne({
      where: { id: payload.sid },
    });

    if (!session || session.revokedAt !== null || session.expiresAt <= new Date()) {
      throw new UnauthorizedException('Session has expired or was revoked. Please log in again.');
    }

    // Verify token hash
    const isValidToken = this.tokenService.compareRefreshToken(
      refreshToken,
      session.refreshTokenHash,
    );

    if (!isValidToken) {
      // Possible token reuse / breach! Revoke session immediately.
      session.revokedAt = new Date();
      await this.sessionRepository.save(session);
      this.logger.warn(`Potential token reuse detected for session: ${session.id}`);
      throw new UnauthorizedException('Invalid refresh token.');
    }

    const user = await this.userRepository.findOne({
      where: { id: session.userId },
    });

    if (!user || user.accountStatus !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('Account is inactive.');
    }

    // Rotate refresh token: generate new pair
    const newTokens = this.tokenService.generateTokens({
      userId: user.id,
      sessionId: session.id,
      phone: PhoneNumberUtil.mask(user.phoneNumber),
      onboarding: user.onboardingCompleted,
    });

    // Update session with new hash and updated expiration
    session.refreshTokenHash = this.tokenService.hashRefreshToken(newTokens.refreshToken);
    session.expiresAt = this.tokenService.getRefreshTokenExpiryDate();
    await this.sessionRepository.save(session);

    return newTokens;
  }

  /**
   * Revoke the current user session on logout.
   */
  async logout(sessionId: string): Promise<{ message: string }> {
    const session = await this.sessionRepository.findOne({
      where: { id: sessionId },
    });

    if (session) {
      session.revokedAt = new Date();
      await this.sessionRepository.save(session);
    }

    return { message: 'Successfully logged out.' };
  }

  /**
   * Get current authenticated user profile.
   */
  async getCurrentUser(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    return {
      id: user.id,
      phoneNumber: PhoneNumberUtil.mask(user.phoneNumber),
      displayName: user.displayName ?? null,
      avatarUrl: user.avatarUrl ?? null,
      onboardingCompleted: user.onboardingCompleted,
      accountStatus: user.accountStatus,
      role: user.role,
      locality: {
        countryCode: user.countryCode ?? 'IN',
        state: user.state ?? null,
        district: user.district ?? null,
        city: user.city ?? null,
        locality: user.locality ?? null,
        neighborhood: user.neighborhood ?? null,
      },
    };
  }
}

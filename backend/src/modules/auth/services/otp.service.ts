import {
  Injectable,
  Inject,
  BadRequestException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'node:crypto';
import { RedisService } from '../../../database/redis.service.js';
import { OTP_PROVIDER, type OtpProvider } from '../interfaces/otp-provider.interface.js';

interface StoredOtpChallenge {
  hash: string;
  attempts: number;
  createdAt: number;
}

export interface RequestOtpResult {
  message: string;
  cooldownSeconds: number;
  expiresInSeconds: number;
  devOtp?: string; // Included only in non-production environments
}

export interface VerifyOtpResult {
  isValid: boolean;
  message?: string;
  attemptsRemaining?: number;
}

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly otpTtlSeconds: number;
  private readonly maxAttempts: number;
  private readonly resendCooldownSeconds: number;
  private readonly isProduction: boolean;

  constructor(
    private readonly redisService: RedisService,
    private readonly configService: ConfigService,
    @Inject(OTP_PROVIDER) private readonly otpProvider: OtpProvider,
  ) {
    this.otpTtlSeconds = this.configService.get<number>('OTP_TTL_SECONDS', 300);
    this.maxAttempts = this.configService.get<number>('OTP_MAX_ATTEMPTS', 5);
    this.resendCooldownSeconds = this.configService.get<number>(
      'OTP_RESEND_COOLDOWN_SECONDS',
      60,
    );
    this.isProduction =
      this.configService.get<string>('NODE_ENV') === 'production';
  }

  /**
   * Generates, stores, and dispatches a 6-digit OTP to the normalized phone number.
   * Enforces resend cooldown and hourly rate limits.
   */
  async requestOtp(normalizedPhone: string): Promise<RequestOtpResult> {
    // 1. Check resend cooldown
    const cooldownKey = `otp:cooldown:${normalizedPhone}`;
    const ttlRemaining = await this.redisService.ttl(cooldownKey);
    if (ttlRemaining > 0) {
      throw new HttpException(
        `Please wait ${ttlRemaining} seconds before requesting a new code.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // 2. Check hourly rate limit (max 5 OTP requests per hour)
    const rateLimitKey = `otp:rate:${normalizedPhone}`;
    const rateCountStr = await this.redisService.get(rateLimitKey);
    const rateCount = rateCountStr ? parseInt(rateCountStr, 10) : 0;
    if (rateCount >= 5) {
      throw new HttpException(
        'Too many OTP requests for this phone number. Please try again in an hour.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // 3. Generate cryptographically secure 6-digit OTP
    const otp = crypto.randomInt(100000, 1000000).toString();
    const hash = crypto.createHash('sha256').update(otp).digest('hex');

    // 4. Save challenge to Redis with TTL
    const challengeKey = `otp:challenge:${normalizedPhone}`;
    const challenge: StoredOtpChallenge = {
      hash,
      attempts: 0,
      createdAt: Date.now(),
    };

    await this.redisService.set(
      challengeKey,
      JSON.stringify(challenge),
      this.otpTtlSeconds,
    );

    // 5. Set resend cooldown
    await this.redisService.set(
      cooldownKey,
      '1',
      this.resendCooldownSeconds,
    );

    // 6. Update rate limiter with 1 hour TTL
    if (rateCount === 0) {
      await this.redisService.set(rateLimitKey, '1', 3600);
    } else {
      const remainingRateTtl = await this.redisService.ttl(rateLimitKey);
      await this.redisService.set(
        rateLimitKey,
        (rateCount + 1).toString(),
        remainingRateTtl > 0 ? remainingRateTtl : 3600,
      );
    }

    // 7. Dispatch OTP via configured provider
    await this.otpProvider.sendOtp(normalizedPhone, otp);

    return {
      message: 'Verification code sent successfully.',
      cooldownSeconds: this.resendCooldownSeconds,
      expiresInSeconds: this.otpTtlSeconds,
      ...(this.isProduction ? {} : { devOtp: otp }),
    };
  }

  /**
   * Verifies the provided 6-digit OTP against the stored challenge.
   * Enforces attempt limits and deletes challenge upon success or lock.
   */
  async verifyOtp(normalizedPhone: string, candidateOtp: string): Promise<VerifyOtpResult> {
    if (!candidateOtp || candidateOtp.length !== 6 || !/^\d{6}$/.test(candidateOtp)) {
      throw new BadRequestException('Verification code must be exactly 6 digits.');
    }

    const challengeKey = `otp:challenge:${normalizedPhone}`;
    const rawChallenge = await this.redisService.get(challengeKey);

    if (!rawChallenge) {
      return {
        isValid: false,
        message: 'Verification code has expired or was not requested. Please request a new code.',
      };
    }

    let challenge: StoredOtpChallenge;
    try {
      challenge = JSON.parse(rawChallenge) as StoredOtpChallenge;
    } catch {
      await this.redisService.del(challengeKey);
      return {
        isValid: false,
        message: 'Invalid verification state. Please request a new code.',
      };
    }

    // Check if max attempts reached
    if (challenge.attempts >= this.maxAttempts) {
      await this.redisService.del(challengeKey);
      throw new HttpException(
        'Too many incorrect attempts. For security, please request a new verification code.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // Hash candidate OTP and perform constant-time comparison
    const candidateHash = crypto.createHash('sha256').update(candidateOtp).digest('hex');
    const hashesMatch =
      candidateHash.length === challenge.hash.length &&
      crypto.timingSafeEqual(
        Buffer.from(candidateHash, 'hex'),
        Buffer.from(challenge.hash, 'hex'),
      );

    if (!hashesMatch) {
      challenge.attempts += 1;
      const attemptsRemaining = this.maxAttempts - challenge.attempts;

      if (attemptsRemaining <= 0) {
        await this.redisService.del(challengeKey);
        throw new HttpException(
          'Too many incorrect attempts. For security, please request a new verification code.',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      // Update remaining attempts in Redis with preserved TTL
      const remainingTtl = await this.redisService.ttl(challengeKey);
      if (remainingTtl > 0) {
        await this.redisService.set(
          challengeKey,
          JSON.stringify(challenge),
          remainingTtl,
        );
      }

      return {
        isValid: false,
        message: `Incorrect code. ${attemptsRemaining} attempt${attemptsRemaining === 1 ? '' : 's'} remaining.`,
        attemptsRemaining,
      };
    }

    // Verification successful! Clean up challenge and cooldown keys.
    await this.redisService.del(challengeKey, `otp:cooldown:${normalizedPhone}`);

    return {
      isValid: true,
      message: 'Verification successful.',
    };
  }
}

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpProvider } from '../interfaces/otp-provider.interface.js';
import { PhoneNumberUtil } from '../utils/phone-number.util.js';

/**
 * Development implementation of OtpProvider.
 *
 * In development/test mode:
 * - Logs the generated OTP to the local development console with masked phone number.
 * - Does not contact external paid SMS gateways.
 *
 * In production:
 * - This provider is NOT used. A dedicated SmsOtpProvider (e.g. AWS SNS, Twilio, Gupshup)
 *   is configured in its place.
 */
@Injectable()
export class DevelopmentOtpProvider implements OtpProvider {
  private readonly logger = new Logger(DevelopmentOtpProvider.name);

  constructor(private readonly configService: ConfigService) {}

  async sendOtp(phoneNumber: string, otp: string): Promise<void> {
    const nodeEnv = this.configService.get<string>('NODE_ENV', 'development');

    // Security guard: Never log plaintext OTPs in production!
    if (nodeEnv === 'production') {
      throw new Error(
        'DevelopmentOtpProvider is strictly prohibited in production environments.',
      );
    }

    const maskedPhone = PhoneNumberUtil.mask(phoneNumber);
    this.logger.debug(
      `[DEV-OTP] Verification code for ${maskedPhone}: ${otp} (Valid for 5 minutes)`,
    );
  }
}

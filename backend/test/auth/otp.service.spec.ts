import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ConfigService } from '@nestjs/config';
import { HttpException } from '@nestjs/common';
import { OtpService } from '../../src/modules/auth/services/otp.service.js';
import { RedisService } from '../../src/database/redis.service.js';
import { OtpProvider } from '../../src/modules/auth/interfaces/otp-provider.interface.js';

describe('OtpService', () => {
  let otpService: OtpService;
  let mockRedisService: Partial<RedisService>;
  let mockConfigService: Partial<ConfigService>;
  let mockOtpProvider: OtpProvider;
  const store = new Map<string, string>();
  const ttls = new Map<string, number>();

  beforeEach(() => {
    store.clear();
    ttls.clear();

    mockRedisService = {
      get: vi.fn(async (key: string) => store.get(key) ?? null),
      set: vi.fn(async (key: string, value: string, ttl?: number) => {
        store.set(key, value);
        if (ttl) ttls.set(key, ttl);
      }),
      del: vi.fn(async (...keys: string[]) => {
        let count = 0;
        for (const k of keys) {
          if (store.delete(k)) count++;
          ttls.delete(k);
        }
        return count;
      }),
      ttl: vi.fn(async (key: string) => (store.has(key) ? (ttls.get(key) ?? -1) : -2)),
    };

    mockConfigService = {
      get: (key: string, defaultValue?: unknown) => {
        const configMap: Record<string, unknown> = {
          OTP_TTL_SECONDS: 300,
          OTP_MAX_ATTEMPTS: 5,
          OTP_RESEND_COOLDOWN_SECONDS: 60,
          NODE_ENV: 'development',
        };
        return configMap[key] ?? defaultValue;
      },
    };

    mockOtpProvider = {
      sendOtp: vi.fn().mockResolvedValue(undefined),
    };

    otpService = new OtpService(
      mockRedisService as RedisService,
      mockConfigService as ConfigService,
      mockOtpProvider,
    );
  });

  it('requests OTP: generates 6-digit code, stores challenge, and dispatches via provider', async () => {
    const phone = '+919876543210';
    const result = await otpService.requestOtp(phone);

    expect(result.message).toBe('Verification code sent successfully.');
    expect(result.cooldownSeconds).toBe(60);
    expect(result.expiresInSeconds).toBe(300);
    expect(result.devOtp).toMatch(/^\d{6}$/);

    expect(mockOtpProvider.sendOtp).toHaveBeenCalledWith(phone, result.devOtp);
    expect(store.has(`otp:challenge:${phone}`)).toBe(true);
    expect(store.has(`otp:cooldown:${phone}`)).toBe(true);
  });

  it('enforces resend cooldown when called within cooldown period', async () => {
    const phone = '+919876543210';
    await otpService.requestOtp(phone);

    // Attempt second request immediately
    await expect(otpService.requestOtp(phone)).rejects.toThrow(HttpException);
  });

  it('verifies valid OTP successfully and removes challenge and cooldown keys', async () => {
    const phone = '+919876543210';
    const reqResult = await otpService.requestOtp(phone);
    const otp = reqResult.devOtp!;

    const verifyResult = await otpService.verifyOtp(phone, otp);
    expect(verifyResult.isValid).toBe(true);
    expect(store.has(`otp:challenge:${phone}`)).toBe(false);
  });

  it('returns invalid on incorrect OTP and decrements remaining attempts', async () => {
    const phone = '+919876543210';
    await otpService.requestOtp(phone);

    const result = await otpService.verifyOtp(phone, '000000');
    expect(result.isValid).toBe(false);
    expect(result.attemptsRemaining).toBe(4);
  });

  it('locks out and removes challenge when max attempts exceeded', async () => {
    const phone = '+919876543210';
    await otpService.requestOtp(phone);

    // 4 failed attempts
    for (let i = 0; i < 4; i++) {
      await otpService.verifyOtp(phone, '000000');
    }

    // 5th attempt should lock out
    await expect(otpService.verifyOtp(phone, '000000')).rejects.toThrow(HttpException);
    expect(store.has(`otp:challenge:${phone}`)).toBe(false);
  });
});

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Repository } from 'typeorm';
import { AuthService } from '../../src/modules/auth/services/auth.service.js';
import { User } from '../../src/modules/users/entities/user.entity.js';
import { AuthSession } from '../../src/modules/auth/entities/auth-session.entity.js';
import { OtpService } from '../../src/modules/auth/services/otp.service.js';
import { TokenService } from '../../src/modules/auth/services/token.service.js';

describe('AuthService', () => {
  let authService: AuthService;
  let mockUserRepo: Partial<Repository<User>>;
  let mockSessionRepo: Partial<Repository<AuthSession>>;
  let mockOtpService: Partial<OtpService>;
  let mockTokenService: Partial<TokenService>;

  beforeEach(() => {
    mockUserRepo = {
      findOne: vi.fn(),
      create: vi.fn((dto) => dto as User),
      save: vi.fn(async (user) => ({ id: 'usr-mock-id', ...user } as User)),
    };

    mockSessionRepo = {
      findOne: vi.fn(),
      create: vi.fn((dto) => dto as AuthSession),
      save: vi.fn(async (session) => ({ id: 'ses-mock-id', ...session } as AuthSession)),
    };

    mockOtpService = {
      requestOtp: vi.fn().mockResolvedValue({
        message: 'Verification code sent successfully.',
        cooldownSeconds: 60,
        expiresInSeconds: 300,
        devOtp: '123456',
      }),
      verifyOtp: vi.fn().mockResolvedValue({
        isValid: true,
        message: 'Verification successful.',
      }),
    };

    mockTokenService = {
      generateTokens: vi.fn().mockReturnValue({
        accessToken: 'mock-access-token',
        refreshToken: 'mock-refresh-token',
        expiresIn: 900,
      }),
      getRefreshTokenExpiryDate: vi.fn().mockReturnValue(new Date(Date.now() + 30 * 86400000)),
      hashRefreshToken: vi.fn().mockReturnValue('mock-hash-64chars'),
      compareRefreshToken: vi.fn().mockReturnValue(true),
      verifyRefreshToken: vi.fn().mockReturnValue({
        sub: 'usr-mock-id',
        sid: 'ses-mock-id',
        jti: 'nonce',
      }),
    };

    authService = new AuthService(
      mockUserRepo as Repository<User>,
      mockSessionRepo as Repository<AuthSession>,
      mockOtpService as OtpService,
      mockTokenService as TokenService,
    );
  });

  it('requestOtp normalizes phone and returns masked phone with cooldown', async () => {
    const res = await authService.requestOtp('9876543210');
    expect(res.maskedPhoneNumber).toBe('+91 ••••••3210');
    expect(res.cooldownSeconds).toBe(60);
    expect(mockOtpService.requestOtp).toHaveBeenCalledWith('+919876543210');
  });

  it('verifyOtp creates new user and session on first login', async () => {
    mockUserRepo.findOne = vi.fn().mockResolvedValue(null);

    const res = await authService.verifyOtp('9876543210', '123456');

    expect(mockUserRepo.create).toHaveBeenCalled();
    expect(mockSessionRepo.create).toHaveBeenCalled();
    expect(res.user.id).toBe('usr-mock-id');
    expect(res.user.phoneNumber).toBe('+91 ••••••3210');
    expect(res.tokens.accessToken).toBe('mock-access-token');
  });

  it('logout marks session as revoked in database', async () => {
    const mockSession = {
      id: 'ses-mock-id',
      revokedAt: null,
    } as AuthSession;
    mockSessionRepo.findOne = vi.fn().mockResolvedValue(mockSession);

    const res = await authService.logout('ses-mock-id');
    expect(res.message).toBe('Successfully logged out.');
    expect(mockSession.revokedAt).toBeInstanceOf(Date);
    expect(mockSessionRepo.save).toHaveBeenCalledWith(mockSession);
  });
});

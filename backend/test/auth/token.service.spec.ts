import { describe, it, expect, beforeEach } from 'vitest';
import { ConfigService } from '@nestjs/config';
import { TokenService } from '../../src/modules/auth/services/token.service.js';

describe('TokenService', () => {
  let tokenService: TokenService;
  let mockConfigService: Partial<ConfigService>;

  beforeEach(() => {
    mockConfigService = {
      get: (key: string, defaultValue?: unknown) => {
        const configMap: Record<string, unknown> = {
          JWT_ACCESS_SECRET: 'test_access_secret_with_32_or_more_characters!',
          JWT_REFRESH_SECRET: 'test_refresh_secret_with_32_or_more_characters!',
          JWT_ACCESS_TTL: '15m',
          JWT_REFRESH_TTL: '30d',
        };
        return configMap[key] ?? defaultValue;
      },
    };

    tokenService = new TokenService(mockConfigService as ConfigService);
  });

  it('generates valid access and refresh token pair', () => {
    const tokens = tokenService.generateTokens({
      userId: 'usr-1234-uuid',
      sessionId: 'ses-5678-uuid',
      phone: '+91 ••••••3210',
      onboarding: false,
    });

    expect(tokens.accessToken).toBeDefined();
    expect(tokens.refreshToken).toBeDefined();
    expect(tokens.expiresIn).toBe(900); // 15m in seconds
  });

  it('verifies and decodes a valid access token', () => {
    const tokens = tokenService.generateTokens({
      userId: 'usr-1234-uuid',
      sessionId: 'ses-5678-uuid',
      phone: '+91 ••••••3210',
      onboarding: true,
    });

    const payload = tokenService.verifyAccessToken(tokens.accessToken);
    expect(payload.sub).toBe('usr-1234-uuid');
    expect(payload.sid).toBe('ses-5678-uuid');
    expect(payload.phone).toBe('+91 ••••••3210');
    expect(payload.onboarding).toBe(true);
    expect(payload.exp).toBeDefined();
  });

  it('verifies and decodes a valid refresh token', () => {
    const tokens = tokenService.generateTokens({
      userId: 'usr-1234-uuid',
      sessionId: 'ses-5678-uuid',
      phone: '+91 ••••••3210',
      onboarding: false,
    });

    const payload = tokenService.verifyRefreshToken(tokens.refreshToken);
    expect(payload.sub).toBe('usr-1234-uuid');
    expect(payload.sid).toBe('ses-5678-uuid');
    expect(payload.jti).toBeDefined();
  });

  it('rejects tampered token signature', () => {
    const tokens = tokenService.generateTokens({
      userId: 'usr-1234-uuid',
      sessionId: 'ses-5678-uuid',
      phone: '+91 ••••••3210',
      onboarding: false,
    });

    const tampered = tokens.accessToken + 'tampered';
    expect(() => tokenService.verifyAccessToken(tampered)).toThrow();
  });

  it('hashes refresh token and securely compares candidate token with hash', () => {
    const rawToken = 'secret-refresh-token-value-12345';
    const hash = tokenService.hashRefreshToken(rawToken);

    expect(hash).toHaveLength(64); // SHA-256 hex string
    expect(tokenService.compareRefreshToken(rawToken, hash)).toBe(true);
    expect(tokenService.compareRefreshToken('wrong-token', hash)).toBe(false);
  });
});

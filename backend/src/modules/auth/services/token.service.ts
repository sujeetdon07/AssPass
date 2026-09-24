import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'node:crypto';

export interface AccessTokenPayload {
  sub: string; // User ID
  sid: string; // Session ID
  phone: string; // Masked phone number
  onboarding: boolean;
  iat?: number;
  exp?: number;
}

export interface RefreshTokenPayload {
  sub: string; // User ID
  sid: string; // Session ID
  jti: string; // Unique token identifier nonce
  iat?: number;
  exp?: number;
}

@Injectable()
export class TokenService {
  private readonly accessSecret: string;
  private readonly refreshSecret: string;
  private readonly accessTtlSeconds: number;
  private readonly refreshTtlSeconds: number;

  constructor(private readonly configService: ConfigService) {
    this.accessSecret =
      this.configService.get<string>('JWT_ACCESS_SECRET') ||
      'default_dev_access_secret_do_not_use_in_production_32chars!';
    this.refreshSecret =
      this.configService.get<string>('JWT_REFRESH_SECRET') ||
      'default_dev_refresh_secret_do_not_use_in_production_32chars!';

    const accessTtl = this.configService.get<string>('JWT_ACCESS_TTL', '15m');
    const refreshTtl = this.configService.get<string>('JWT_REFRESH_TTL', '30d');

    this.accessTtlSeconds = this.parseDurationToSeconds(accessTtl);
    this.refreshTtlSeconds = this.parseDurationToSeconds(refreshTtl);
  }

  /**
   * Generates a pair of access and refresh tokens.
   */
  generateTokens(params: {
    userId: string;
    sessionId: string;
    phone: string;
    onboarding: boolean;
  }): { accessToken: string; refreshToken: string; expiresIn: number } {
    const accessToken = this.signAccessToken({
      sub: params.userId,
      sid: params.sessionId,
      phone: params.phone,
      onboarding: params.onboarding,
    });

    const refreshToken = this.signRefreshToken({
      sub: params.userId,
      sid: params.sessionId,
      jti: crypto.randomBytes(16).toString('hex'),
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: this.accessTtlSeconds,
    };
  }

  /**
   * Signs a JWT access token using HMAC-SHA256 (HS256).
   */
  signAccessToken(payload: Omit<AccessTokenPayload, 'iat' | 'exp'>): string {
    const now = Math.floor(Date.now() / 1000);
    const fullPayload: AccessTokenPayload = {
      ...payload,
      iat: now,
      exp: now + this.accessTtlSeconds,
    };
    return this.signJwt(fullPayload, this.accessSecret);
  }

  /**
   * Signs a JWT refresh token using HMAC-SHA256 (HS256).
   */
  signRefreshToken(payload: Omit<RefreshTokenPayload, 'iat' | 'exp'>): string {
    const now = Math.floor(Date.now() / 1000);
    const fullPayload: RefreshTokenPayload = {
      ...payload,
      iat: now,
      exp: now + this.refreshTtlSeconds,
    };
    return this.signJwt(fullPayload, this.refreshSecret);
  }

  /**
   * Verifies and decodes a JWT access token.
   */
  verifyAccessToken(token: string): AccessTokenPayload {
    return this.verifyJwt<AccessTokenPayload>(token, this.accessSecret);
  }

  /**
   * Verifies and decodes a JWT refresh token.
   */
  verifyRefreshToken(token: string): RefreshTokenPayload {
    return this.verifyJwt<RefreshTokenPayload>(token, this.refreshSecret);
  }

  /**
   * Computes SHA-256 hash of a refresh token to safely store in database.
   */
  hashRefreshToken(refreshToken: string): string {
    return crypto.createHash('sha256').update(refreshToken).digest('hex');
  }

  /**
   * Constant-time comparison between a candidate refresh token and a stored hash.
   */
  compareRefreshToken(refreshToken: string, storedHash: string): boolean {
    const candidateHash = this.hashRefreshToken(refreshToken);
    if (candidateHash.length !== storedHash.length) return false;
    return crypto.timingSafeEqual(
      Buffer.from(candidateHash, 'hex'),
      Buffer.from(storedHash, 'hex'),
    );
  }

  /**
   * Returns expiry Date for a newly issued refresh token.
   */
  getRefreshTokenExpiryDate(): Date {
    return new Date(Date.now() + this.refreshTtlSeconds * 1000);
  }

  // ── Standard RFC 7519 JWT HS256 Implementation ─────────────────────────────

  private signJwt(payload: object, secret: string): string {
    const header = { alg: 'HS256', typ: 'JWT' };
    const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
    const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const signature = crypto
      .createHmac('sha256', secret)
      .update(`${encodedHeader}.${encodedPayload}`)
      .digest('base64url');

    return `${encodedHeader}.${encodedPayload}.${signature}`;
  }

  private verifyJwt<T extends { exp?: number; iat?: number }>(
    token: string,
    secret: string,
  ): T {
    if (!token || typeof token !== 'string') {
      throw new UnauthorizedException('Token must be provided.');
    }

    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new UnauthorizedException('Malformed token format.');
    }

    const [encodedHeader, encodedPayload, signature] = parts;
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(`${encodedHeader}.${encodedPayload}`)
      .digest('base64url');

    // Constant-time signature verification
    const sigBuffer = Buffer.from(signature);
    const expectedBuffer = Buffer.from(expectedSignature);

    if (
      sigBuffer.length !== expectedBuffer.length ||
      !crypto.timingSafeEqual(sigBuffer, expectedBuffer)
    ) {
      throw new UnauthorizedException('Invalid token signature.');
    }

    let payload: T;
    try {
      const decodedPayload = Buffer.from(encodedPayload, 'base64url').toString('utf8');
      payload = JSON.parse(decodedPayload) as T;
    } catch {
      throw new UnauthorizedException('Invalid token payload encoding.');
    }

    const now = Math.floor(Date.now() / 1000);

    // Verify token expiration
    if (payload.exp !== undefined && payload.exp < now) {
      throw new UnauthorizedException('Token has expired.');
    }

    // Verify issued-at time with 60s clock skew tolerance
    if (payload.iat !== undefined && payload.iat > now + 60) {
      throw new UnauthorizedException('Token issued in the future.');
    }

    return payload;
  }

  private parseDurationToSeconds(duration: string): number {
    const match = duration.match(/^(\d+)([smhd])$/);
    if (!match || !match[1] || !match[2]) {
      return 900; // 15 minutes default
    }

    const value = parseInt(match[1], 10);
    const unit = match[2];

    switch (unit) {
      case 's':
        return value;
      case 'm':
        return value * 60;
      case 'h':
        return value * 3600;
      case 'd':
        return value * 86400;
      default:
        return 900;
    }
  }
}

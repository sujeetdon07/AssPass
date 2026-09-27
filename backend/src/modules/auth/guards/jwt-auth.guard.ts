import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Request } from 'express';
import { TokenService } from '../services/token.service.js';
import { AuthSession } from '../entities/auth-session.entity.js';
import { User, UserStatus } from '../../users/entities/user.entity.js';
import { CurrentUserPayload } from '../decorators/current-user.decorator.js';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly tokenService: TokenService,
    @InjectRepository(AuthSession)
    private readonly sessionRepository: Repository<AuthSession>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request & { user?: CurrentUserPayload }>();
    const authHeader = request.headers['authorization'];

    if (!authHeader || typeof authHeader !== 'string') {
      throw new UnauthorizedException('Authentication token is required.');
    }

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0]?.toLowerCase() !== 'bearer' || !parts[1]) {
      throw new UnauthorizedException('Invalid authorization header format. Expected "Bearer <token>".');
    }

    const token = parts[1];
    let payload;
    try {
      payload = this.tokenService.verifyAccessToken(token);
    } catch {
      throw new UnauthorizedException('Authentication token is invalid or expired.');
    }

    // Verify session validity against database
    const session = await this.sessionRepository.findOne({
      where: { id: payload.sid },
    });

    if (!session || session.revokedAt !== null || session.expiresAt <= new Date()) {
      throw new UnauthorizedException('Session is invalid or has been revoked. Please log in again.');
    }

    // Verify user exists and is active
    const user = await this.userRepository.findOne({
      where: { id: payload.sub },
    });

    if (!user || user.accountStatus !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('Account is inactive, suspended, or does not exist.');
    }

    // Attach user payload to request
    request.user = {
      userId: user.id,
      sessionId: session.id,
      phoneNumber: user.phoneNumber,
      onboarding: user.onboardingCompleted,
      role: user.role,
    };

    return true;
  }
}

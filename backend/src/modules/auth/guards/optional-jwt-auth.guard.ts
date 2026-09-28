import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Request } from 'express';
import { TokenService } from '../services/token.service.js';
import { AuthSession } from '../entities/auth-session.entity.js';
import { User, UserStatus } from '../../users/entities/user.entity.js';
import { CurrentUserPayload } from '../decorators/current-user.decorator.js';

@Injectable()
export class OptionalJwtAuthGuard implements CanActivate {
  constructor(
    private readonly tokenService: TokenService,
    @InjectRepository(AuthSession)
    private readonly sessionRepository: Repository<AuthSession>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context
      .switchToHttp()
      .getRequest<Request & { user?: CurrentUserPayload }>();
    const authHeader = request.headers['authorization'];

    if (!authHeader || typeof authHeader !== 'string') {
      return true;
    }

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0]?.toLowerCase() !== 'bearer' || !parts[1]) {
      return true;
    }

    try {
      const payload = this.tokenService.verifyAccessToken(parts[1]);
      const session = await this.sessionRepository.findOne({
        where: { id: payload.sid },
      });

      if (!session || session.revokedAt !== null || session.expiresAt <= new Date()) {
        return true;
      }

      const user = await this.userRepository.findOne({
        where: { id: payload.sub },
      });

      if (!user || user.accountStatus !== UserStatus.ACTIVE) {
        return true;
      }

      request.user = {
        userId: user.id,
        sessionId: session.id,
        phoneNumber: user.phoneNumber,
        onboarding: user.onboardingCompleted,
        role: user.role,
      };
    } catch {
      // Ignore invalid token in optional guard
    }

    return true;
  }
}

import { CanActivate, ExecutionContext, Injectable, Logger } from '@nestjs/common';
import { WsException } from '@nestjs/websockets';
import { Socket } from 'socket.io';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TokenService } from '../../auth/services/token.service.js';
import { AuthSession } from '../../auth/entities/auth-session.entity.js';
import { User, UserStatus } from '../../users/entities/user.entity.js';

export interface AuthenticatedSocketUser {
  userId: string;
  sessionId: string;
  phoneNumber: string;
}

@Injectable()
export class WsJwtGuard implements CanActivate {
  private readonly logger = new Logger(WsJwtGuard.name);

  constructor(
    private readonly tokenService: TokenService,
    @InjectRepository(AuthSession)
    private readonly sessionRepository: Repository<AuthSession>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const client: Socket = context.switchToWs().getClient<Socket>();
    const user = client.data?.user as AuthenticatedSocketUser | undefined;

    if (user && user.userId) {
      return true;
    }

    // Try to authenticate from socket handshake
    const authenticated = await this.authenticateSocket(client);
    if (!authenticated) {
      throw new WsException('Unauthorized: WebSocket authentication failed.');
    }
    return true;
  }

  async authenticateSocket(client: Socket): Promise<AuthenticatedSocketUser | null> {
    try {
      const authHeader =
        (client.handshake.auth?.token as string) ||
        (client.handshake.headers['authorization'] as string) ||
        (client.handshake.query?.token as string);

      if (!authHeader) {
        return null;
      }

      const token = authHeader.startsWith('Bearer ')
        ? authHeader.substring(7)
        : authHeader;

      const payload = this.tokenService.verifyAccessToken(token);

      const session = await this.sessionRepository.findOne({
        where: { id: payload.sid },
      });

      if (!session || session.revokedAt !== null || session.expiresAt <= new Date()) {
        return null;
      }

      const user = await this.userRepository.findOne({
        where: { id: payload.sub },
      });

      if (!user || user.accountStatus !== UserStatus.ACTIVE) {
        return null;
      }

      const socketUser: AuthenticatedSocketUser = {
        userId: user.id,
        sessionId: session.id,
        phoneNumber: user.phoneNumber,
      };

      client.data = {
        ...client.data,
        user: socketUser,
      };

      return socketUser;
    } catch {
      return null;
    }
  }
}

import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { AuthSession } from './entities/auth-session.entity.js';
import { User } from '../users/entities/user.entity.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './services/auth.service.js';
import { OtpService } from './services/otp.service.js';
import { TokenService } from './services/token.service.js';
import { JwtAuthGuard } from './guards/jwt-auth.guard.js';
import { OptionalJwtAuthGuard } from './guards/optional-jwt-auth.guard.js';
import { OTP_PROVIDER } from './interfaces/otp-provider.interface.js';
import { DevelopmentOtpProvider } from './providers/development-otp.provider.js';
import { UsersModule } from '../users/users.module.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([AuthSession, User]),
    ConfigModule,
    forwardRef(() => UsersModule),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    TokenService,
    JwtAuthGuard,
    OptionalJwtAuthGuard,
    {
      provide: OTP_PROVIDER,
      useClass: DevelopmentOtpProvider,
    },
  ],
  exports: [AuthService, TokenService, JwtAuthGuard, OptionalJwtAuthGuard, TypeOrmModule],
})
export class AuthModule {}

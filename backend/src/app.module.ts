import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TerminusModule } from '@nestjs/terminus';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';

import { validateConfig } from './config/config.validation.js';
import { HealthModule } from './health/health.module.js';
import { RedisModule } from './database/redis.module.js';
import { AuthModule } from './modules/auth/auth.module.js';
import { UsersModule } from './modules/users/users.module.js';
import { LocalitiesModule } from './modules/localities/localities.module.js';
import { FeedModule } from './modules/feed/feed.module.js';
import { NearbyModule } from './modules/nearby/nearby.module.js';
import { CommunitiesModule } from './modules/communities/communities.module.js';
import { MarketplaceModule } from './modules/marketplace/marketplace.module.js';
import { BusinessesModule } from './modules/businesses/businesses.module.js';
import { ServicesModule } from './modules/services/services.module.js';
import { MessagingModule } from './modules/messaging/messaging.module.js';
import { NotificationsModule } from './modules/notifications/notifications.module.js';
import { EventsModule } from './modules/events/events.module.js';
import { SafetyModule } from './modules/safety/safety.module.js';
import { AdminModule } from './modules/admin/admin.module.js';
import { MediaModule } from './modules/media/media.module.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

@Module({
  imports: [
    // ── Configuration ────────────────────────────────────────────────────────
    ConfigModule.forRoot({
      isGlobal: true,        // Available in all modules without re-importing.
      envFilePath: '.env',
      validate: validateConfig,
      expandVariables: true,
    }),

    // ── Database (PostgreSQL + PostGIS via TypeORM) ───────────────────────────
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        url: configService.get<string>('DATABASE_URL'),
        entities: [__dirname + '/**/*.entity{.ts,.js}'],
        migrations: [__dirname + '/database/migrations/*{.ts,.js}'],
        synchronize: false, // NEVER use synchronize:true in production.
        logging: configService.get<string>('NODE_ENV') === 'development',
        ssl:
          configService.get<string>('DATABASE_SSL') === 'true'
            ? { rejectUnauthorized: false }
            : false,
        // PostGIS requires the pg driver with spatial support.
        // Entities will use 'geometry' columns via typeorm with pg.
        extra: {
          max: Number(configService.get<number>('DATABASE_POOL_MAX', 20)),
          idleTimeoutMillis: Number(configService.get<number>('DATABASE_POOL_IDLE_TIMEOUT_MS', 30000)),
          connectionTimeoutMillis: Number(configService.get<number>('DATABASE_POOL_CONNECT_TIMEOUT_MS', 3000)),
        },
      }),
    }),

    // ── Redis ─────────────────────────────────────────────────────────────────
    RedisModule,

    // ── Terminus (health checks) ──────────────────────────────────────────────
    TerminusModule,

    // ── Feature modules ───────────────────────────────────────────────────────
    HealthModule,
    AuthModule,
    UsersModule,
    LocalitiesModule,
    FeedModule,
    NearbyModule,
    CommunitiesModule,
    MarketplaceModule,
    BusinessesModule,
    ServicesModule,
    MessagingModule,
    NotificationsModule,
    EventsModule,
    SafetyModule,
    AdminModule,
    MediaModule,
  ],
})
export class AppModule {}

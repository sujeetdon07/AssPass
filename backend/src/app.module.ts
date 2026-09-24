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
          max: 20, // Maximum pool connections.
          idleTimeoutMillis: 30000,
          connectionTimeoutMillis: 2000,
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
  ],
})
export class AppModule {}

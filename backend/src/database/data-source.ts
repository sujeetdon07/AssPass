import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { config } from 'dotenv';

// Load .env for use outside of NestJS context (e.g., migrations CLI).
config();

/**
 * TypeORM DataSource for use with the TypeORM CLI (migrations).
 *
 * This is separate from the NestJS TypeORM module configuration
 * because the CLI cannot use the NestJS DI container.
 *
 * Usage:
 *   npm run migration:generate -- --name=MigrationName
 *   npm run migration:run
 *   npm run migration:revert
 */
export const AppDataSource = new DataSource({
  type: 'postgres',
  url: process.env['DATABASE_URL'],
  entities: ['src/**/*.entity.ts'],
  migrations: ['src/database/migrations/*.ts'],
  synchronize: false, // NEVER true in production.
  logging: process.env['NODE_ENV'] === 'development',
  ssl:
    process.env['DATABASE_SSL'] === 'true'
      ? { rejectUnauthorized: false }
      : false,
});

export default AppDataSource;

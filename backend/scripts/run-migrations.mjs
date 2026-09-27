import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { config } from 'dotenv';
import { CreateAuthAndUsersTables1727000000000 } from '../dist/database/migrations/1727000000000-CreateAuthAndUsersTables.js';
import { CreateFeedTables1727100000000 } from '../dist/database/migrations/1727100000000-CreateFeedTables.js';
import { AddSpatialLocationToPosts1727200000000 } from '../dist/database/migrations/1727200000000-AddSpatialLocationToPosts.js';
import { CreateCommunitiesTables1727300000000 } from '../dist/database/migrations/1727300000000-CreateCommunitiesTables.js';
import { CreateMarketplaceTables1727400000000 } from '../dist/database/migrations/1727400000000-CreateMarketplaceTables.js';
import { CreateBusinessesAndServicesTables1727500000000 } from '../dist/database/migrations/1727500000000-CreateBusinessesAndServicesTables.js';
import { CreateMessagingTables1727600000000 } from '../dist/database/migrations/1727600000000-CreateMessagingTables.js';
import { CreateNotificationsTables1727700000000 } from '../dist/database/migrations/1727700000000-CreateNotificationsTables.js';
import { CreateSafetyAndModerationTables1727800000000 } from '../dist/database/migrations/1727800000000-CreateSafetyAndModerationTables.js';
import { AddPhase12PerformanceIndexes1727900000000 } from '../dist/database/migrations/1727900000000-AddPhase12PerformanceIndexes.js';
import { CreateEventsTables1728000000000 } from '../dist/database/migrations/1728000000000-CreateEventsTables.js';
import { AddUserBioAndVerification1728100000000 } from '../dist/database/migrations/1728100000000-AddUserBioAndVerification.js';
config();

const ds = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  entities: [],
  migrations: [
    CreateAuthAndUsersTables1727000000000,
    CreateFeedTables1727100000000,
    AddSpatialLocationToPosts1727200000000,
    CreateCommunitiesTables1727300000000,
    CreateMarketplaceTables1727400000000,
    CreateBusinessesAndServicesTables1727500000000,
    CreateMessagingTables1727600000000,
    CreateNotificationsTables1727700000000,
    CreateSafetyAndModerationTables1727800000000,
    AddPhase12PerformanceIndexes1727900000000,
    CreateEventsTables1728000000000,
    AddUserBioAndVerification1728100000000,
  ],
  logging: true,
});

async function main() {
  await ds.initialize();
  console.log('[Migration] DataSource initialized. Running migrations...');
  const migrations = await ds.runMigrations();
  console.log('[Migration] Successfully executed migrations:', migrations.map(m => m.name));
  await ds.destroy();
}

main().catch(err => {
  console.error('[Migration] Failed:', err);
  process.exit(1);
});

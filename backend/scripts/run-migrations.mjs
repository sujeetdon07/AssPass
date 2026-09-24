import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { config } from 'dotenv';
import { CreateAuthAndUsersTables1727000000000 } from '../dist/database/migrations/1727000000000-CreateAuthAndUsersTables.js';
import { CreateFeedTables1727100000000 } from '../dist/database/migrations/1727100000000-CreateFeedTables.js';
import { AddSpatialLocationToPosts1727200000000 } from '../dist/database/migrations/1727200000000-AddSpatialLocationToPosts.js';
import { CreateCommunitiesTables1727300000000 } from '../dist/database/migrations/1727300000000-CreateCommunitiesTables.js';
import { CreateMarketplaceTables1727400000000 } from '../dist/database/migrations/1727400000000-CreateMarketplaceTables.js';
import { CreateBusinessesAndServicesTables1727500000000 } from '../dist/database/migrations/1727500000000-CreateBusinessesAndServicesTables.js';
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

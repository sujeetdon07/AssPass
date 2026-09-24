import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddSpatialLocationToPosts1727200000000 implements MigrationInterface {
  name = 'AddSpatialLocationToPosts1727200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Ensure PostGIS extension is enabled
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS postgis;`);

    // 2. Add spatial location geography point column to posts
    await queryRunner.query(`
      ALTER TABLE "posts"
      ADD COLUMN IF NOT EXISTS "location" geography(Point, 4326);
    `);

    // 3. Create GiST spatial index for radius queries
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_posts_location_gist"
      ON "posts" USING GIST ("location")
      WHERE "deletedAt" IS NULL;
    `);

    // 4. Backfill existing posts based on known locality centroids
    // Indiranagar, Bengaluru -> 77.6408, 12.9784
    await queryRunner.query(`
      UPDATE "posts"
      SET "location" = ST_SetSRID(ST_MakePoint(77.6408, 12.9784), 4326)::geography
      WHERE "location" IS NULL AND LOWER("locality") LIKE '%indiranagar%';
    `);

    // Koramangala, Bengaluru -> 77.6245, 12.9352
    await queryRunner.query(`
      UPDATE "posts"
      SET "location" = ST_SetSRID(ST_MakePoint(77.6245, 12.9352), 4326)::geography
      WHERE "location" IS NULL AND LOWER("locality") LIKE '%koramangala%';
    `);

    // HSR Layout, Bengaluru -> 77.6446, 12.9121
    await queryRunner.query(`
      UPDATE "posts"
      SET "location" = ST_SetSRID(ST_MakePoint(77.6446, 12.9121), 4326)::geography
      WHERE "location" IS NULL AND LOWER("locality") LIKE '%hsr%';
    `);

    // Whitefield, Bengaluru -> 77.7500, 12.9698
    await queryRunner.query(`
      UPDATE "posts"
      SET "location" = ST_SetSRID(ST_MakePoint(77.7500, 12.9698), 4326)::geography
      WHERE "location" IS NULL AND LOWER("locality") LIKE '%whitefield%';
    `);

    // Fallback for remaining Bengaluru posts -> 77.5946, 12.9716 (City centroid)
    await queryRunner.query(`
      UPDATE "posts"
      SET "location" = ST_SetSRID(ST_MakePoint(77.5946, 12.9716), 4326)::geography
      WHERE "location" IS NULL AND LOWER("city") LIKE '%bengaluru%';
    `);

    // Connaught Place / Delhi -> 77.2167, 28.6315
    await queryRunner.query(`
      UPDATE "posts"
      SET "location" = ST_SetSRID(ST_MakePoint(77.2167, 28.6315), 4326)::geography
      WHERE "location" IS NULL AND (LOWER("city") LIKE '%delhi%' OR LOWER("locality") LIKE '%connaught%');
    `);

    // Bandra / Mumbai -> 72.8295, 19.0596
    await queryRunner.query(`
      UPDATE "posts"
      SET "location" = ST_SetSRID(ST_MakePoint(72.8295, 19.0596), 4326)::geography
      WHERE "location" IS NULL AND (LOWER("city") LIKE '%mumbai%' OR LOWER("locality") LIKE '%bandra%');
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_posts_location_gist";`);
    await queryRunner.query(`ALTER TABLE "posts" DROP COLUMN IF EXISTS "location";`);
  }
}

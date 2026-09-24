import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateMarketplaceTables1727400000000 implements MigrationInterface {
  name = 'CreateMarketplaceTables1727400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create Enums
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "marketplace_category_enum" AS ENUM (
          'electronics', 'mobiles', 'computers', 'furniture', 'home_kitchen',
          'vehicles', 'books', 'fashion', 'kids', 'sports', 'other'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "marketplace_condition_enum" AS ENUM (
          'new', 'like_new', 'good', 'fair', 'used'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "marketplace_status_enum" AS ENUM (
          'active', 'sold', 'archived'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "marketplace_report_reason_enum" AS ENUM (
          'spam', 'scam', 'harassment', 'inappropriate', 'misinformation', 'other'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "marketplace_report_status_enum" AS ENUM (
          'pending', 'reviewed', 'dismissed'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 2. Create marketplace_listings table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "marketplace_listings" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "sellerId" uuid NOT NULL,
        "title" character varying(120) NOT NULL,
        "description" text NOT NULL,
        "category" "marketplace_category_enum" NOT NULL,
        "price" numeric(12, 2) NOT NULL DEFAULT 0.00,
        "currency" character varying(10) NOT NULL DEFAULT 'INR',
        "condition" "marketplace_condition_enum" NOT NULL,
        "status" "marketplace_status_enum" NOT NULL DEFAULT 'active',
        "countryCode" character varying(5) NOT NULL DEFAULT 'IN',
        "state" character varying(100),
        "district" character varying(100),
        "city" character varying(100),
        "locality" character varying(150),
        "neighborhood" character varying(150),
        "location" geography(Point, 4326),
        "favoriteCount" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deletedAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_marketplace_listings_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_marketplace_listings_sellerId" FOREIGN KEY ("sellerId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listings_sellerId" ON "marketplace_listings" ("sellerId");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listings_category" ON "marketplace_listings" ("category");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listings_condition" ON "marketplace_listings" ("condition");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listings_status" ON "marketplace_listings" ("status");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listings_price" ON "marketplace_listings" ("price");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listings_city_locality" ON "marketplace_listings" ("city", "locality");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listings_createdAt" ON "marketplace_listings" ("createdAt");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listings_deletedAt" ON "marketplace_listings" ("deletedAt");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listings_location_gist"
        ON "marketplace_listings" USING GIST ("location")
        WHERE "deletedAt" IS NULL;
    `);

    // 3. Create marketplace_listing_images table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "marketplace_listing_images" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "listingId" uuid NOT NULL,
        "url" character varying(500) NOT NULL,
        "displayOrder" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_marketplace_listing_images_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_marketplace_listing_images_listingId" FOREIGN KEY ("listingId")
          REFERENCES "marketplace_listings"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_listing_images_listingId" ON "marketplace_listing_images" ("listingId");
    `);

    // 4. Create marketplace_favorites table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "marketplace_favorites" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "listingId" uuid NOT NULL,
        "userId" uuid NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_marketplace_favorites_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_marketplace_favorites_listing_user" UNIQUE ("listingId", "userId"),
        CONSTRAINT "FK_marketplace_favorites_listingId" FOREIGN KEY ("listingId")
          REFERENCES "marketplace_listings"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_marketplace_favorites_userId" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_favorites_listingId" ON "marketplace_favorites" ("listingId");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_favorites_userId" ON "marketplace_favorites" ("userId");
    `);

    // 5. Create marketplace_reports table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "marketplace_reports" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "listingId" uuid NOT NULL,
        "reporterId" uuid NOT NULL,
        "reason" "marketplace_report_reason_enum" NOT NULL,
        "details" character varying(500),
        "status" "marketplace_report_status_enum" NOT NULL DEFAULT 'pending',
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_marketplace_reports_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_marketplace_reports_listing_reporter" UNIQUE ("listingId", "reporterId"),
        CONSTRAINT "FK_marketplace_reports_listingId" FOREIGN KEY ("listingId")
          REFERENCES "marketplace_listings"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_marketplace_reports_reporterId" FOREIGN KEY ("reporterId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_reports_listingId" ON "marketplace_reports" ("listingId");
      CREATE INDEX IF NOT EXISTS "IDX_marketplace_reports_reporterId" ON "marketplace_reports" ("reporterId");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "marketplace_reports";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "marketplace_favorites";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "marketplace_listing_images";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "marketplace_listings";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "marketplace_report_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "marketplace_report_reason_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "marketplace_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "marketplace_condition_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "marketplace_category_enum";`);
  }
}

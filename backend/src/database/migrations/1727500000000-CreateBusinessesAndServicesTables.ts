import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateBusinessesAndServicesTables1727500000000 implements MigrationInterface {
  name = 'CreateBusinessesAndServicesTables1727500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create Enums for Businesses
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "business_category_enum" AS ENUM (
          'food_dining', 'grocery', 'shopping', 'health', 'beauty',
          'fitness', 'education', 'electronics', 'home_repair',
          'automotive', 'professional', 'other'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "business_status_enum" AS ENUM (
          'active', 'inactive', 'archived'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "business_verification_status_enum" AS ENUM (
          'unverified', 'pending', 'verified'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "business_report_reason_enum" AS ENUM (
          'incorrect_info', 'spam', 'fraud_scam', 'inappropriate',
          'duplicate', 'closed_business', 'other'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "business_report_status_enum" AS ENUM (
          'pending', 'reviewed', 'dismissed'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 2. Create Enums for Services
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "service_category_enum" AS ENUM (
          'home_repair', 'education', 'beauty', 'cleaning',
          'photography', 'automotive', 'technology', 'personal_services', 'other'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "service_status_enum" AS ENUM (
          'active', 'inactive', 'archived'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "service_verification_status_enum" AS ENUM (
          'unverified', 'pending', 'verified'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "service_report_reason_enum" AS ENUM (
          'incorrect_info', 'spam', 'fraud_scam', 'inappropriate',
          'duplicate', 'closed_business', 'other'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "service_report_status_enum" AS ENUM (
          'pending', 'reviewed', 'dismissed'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 3. Create businesses table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "businesses" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "ownerId" uuid NOT NULL,
        "name" character varying(150) NOT NULL,
        "slug" character varying(180) NOT NULL,
        "description" text NOT NULL,
        "category" "business_category_enum" NOT NULL,
        "status" "business_status_enum" NOT NULL DEFAULT 'active',
        "verificationStatus" "business_verification_status_enum" NOT NULL DEFAULT 'unverified',
        "countryCode" character varying(5) NOT NULL DEFAULT 'IN',
        "state" character varying(100),
        "district" character varying(100),
        "city" character varying(100),
        "locality" character varying(150),
        "neighborhood" character varying(150),
        "address" character varying(250),
        "location" geography(Point, 4326),
        "contactPhone" character varying(25),
        "contactEmail" character varying(120),
        "website" character varying(255),
        "timezone" character varying(50) NOT NULL DEFAULT 'Asia/Kolkata',
        "operatingHours" jsonb,
        "favoriteCount" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deletedAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_businesses_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_businesses_ownerId" FOREIGN KEY ("ownerId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_businesses_ownerId" ON "businesses" ("ownerId");
      CREATE INDEX IF NOT EXISTS "IDX_businesses_category" ON "businesses" ("category");
      CREATE INDEX IF NOT EXISTS "IDX_businesses_status" ON "businesses" ("status");
      CREATE INDEX IF NOT EXISTS "IDX_businesses_city_locality" ON "businesses" ("city", "locality");
      CREATE INDEX IF NOT EXISTS "IDX_businesses_createdAt" ON "businesses" ("createdAt");
      CREATE INDEX IF NOT EXISTS "IDX_businesses_deletedAt" ON "businesses" ("deletedAt");
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_businesses_slug" ON "businesses" ("slug") WHERE "deletedAt" IS NULL;
      CREATE INDEX IF NOT EXISTS "IDX_businesses_location_gist"
        ON "businesses" USING GIST ("location")
        WHERE "deletedAt" IS NULL;
    `);

    // 4. Create business_images table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "business_images" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "businessId" uuid NOT NULL,
        "url" character varying(500) NOT NULL,
        "displayOrder" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_business_images_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_business_images_businessId" FOREIGN KEY ("businessId")
          REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_business_images_businessId" ON "business_images" ("businessId");
    `);

    // 5. Create business_services table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "business_services" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "businessId" uuid NOT NULL,
        "name" character varying(120) NOT NULL,
        "description" text,
        "startingPrice" numeric(12, 2),
        "currency" character varying(10) NOT NULL DEFAULT 'INR',
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_business_services_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_business_services_businessId" FOREIGN KEY ("businessId")
          REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_business_services_businessId" ON "business_services" ("businessId");
    `);

    // 6. Create business_favorites table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "business_favorites" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "businessId" uuid NOT NULL,
        "userId" uuid NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_business_favorites_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_business_favorites_business_user" UNIQUE ("businessId", "userId"),
        CONSTRAINT "FK_business_favorites_businessId" FOREIGN KEY ("businessId")
          REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_business_favorites_userId" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_business_favorites_businessId" ON "business_favorites" ("businessId");
      CREATE INDEX IF NOT EXISTS "IDX_business_favorites_userId" ON "business_favorites" ("userId");
    `);

    // 7. Create business_reports table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "business_reports" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "businessId" uuid NOT NULL,
        "reporterId" uuid NOT NULL,
        "reason" "business_report_reason_enum" NOT NULL,
        "details" character varying(500),
        "status" "business_report_status_enum" NOT NULL DEFAULT 'pending',
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_business_reports_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_business_reports_business_reporter" UNIQUE ("businessId", "reporterId"),
        CONSTRAINT "FK_business_reports_businessId" FOREIGN KEY ("businessId")
          REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_business_reports_reporterId" FOREIGN KEY ("reporterId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_business_reports_businessId" ON "business_reports" ("businessId");
      CREATE INDEX IF NOT EXISTS "IDX_business_reports_reporterId" ON "business_reports" ("reporterId");
    `);

    // 8. Create service_listings table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "service_listings" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "ownerId" uuid NOT NULL,
        "title" character varying(150) NOT NULL,
        "description" text NOT NULL,
        "category" "service_category_enum" NOT NULL,
        "status" "service_status_enum" NOT NULL DEFAULT 'active',
        "verificationStatus" "service_verification_status_enum" NOT NULL DEFAULT 'unverified',
        "countryCode" character varying(5) NOT NULL DEFAULT 'IN',
        "state" character varying(100),
        "district" character varying(100),
        "city" character varying(100),
        "locality" character varying(150),
        "neighborhood" character varying(150),
        "serviceRadiusKm" integer NOT NULL DEFAULT 10,
        "location" geography(Point, 4326),
        "contactPhone" character varying(25),
        "contactEmail" character varying(120),
        "experienceYears" integer,
        "availability" character varying(200),
        "startingPrice" numeric(12, 2),
        "currency" character varying(10) NOT NULL DEFAULT 'INR',
        "favoriteCount" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deletedAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_service_listings_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_service_listings_ownerId" FOREIGN KEY ("ownerId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_service_listings_ownerId" ON "service_listings" ("ownerId");
      CREATE INDEX IF NOT EXISTS "IDX_service_listings_category" ON "service_listings" ("category");
      CREATE INDEX IF NOT EXISTS "IDX_service_listings_status" ON "service_listings" ("status");
      CREATE INDEX IF NOT EXISTS "IDX_service_listings_city_locality" ON "service_listings" ("city", "locality");
      CREATE INDEX IF NOT EXISTS "IDX_service_listings_createdAt" ON "service_listings" ("createdAt");
      CREATE INDEX IF NOT EXISTS "IDX_service_listings_deletedAt" ON "service_listings" ("deletedAt");
      CREATE INDEX IF NOT EXISTS "IDX_service_listings_location_gist"
        ON "service_listings" USING GIST ("location")
        WHERE "deletedAt" IS NULL;
    `);

    // 9. Create service_favorites table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "service_favorites" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "serviceId" uuid NOT NULL,
        "userId" uuid NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_service_favorites_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_service_favorites_service_user" UNIQUE ("serviceId", "userId"),
        CONSTRAINT "FK_service_favorites_serviceId" FOREIGN KEY ("serviceId")
          REFERENCES "service_listings"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_service_favorites_userId" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_service_favorites_serviceId" ON "service_favorites" ("serviceId");
      CREATE INDEX IF NOT EXISTS "IDX_service_favorites_userId" ON "service_favorites" ("userId");
    `);

    // 10. Create service_reports table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "service_reports" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "serviceId" uuid NOT NULL,
        "reporterId" uuid NOT NULL,
        "reason" "service_report_reason_enum" NOT NULL,
        "details" character varying(500),
        "status" "service_report_status_enum" NOT NULL DEFAULT 'pending',
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_service_reports_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_service_reports_service_reporter" UNIQUE ("serviceId", "reporterId"),
        CONSTRAINT "FK_service_reports_serviceId" FOREIGN KEY ("serviceId")
          REFERENCES "service_listings"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_service_reports_reporterId" FOREIGN KEY ("reporterId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_service_reports_serviceId" ON "service_reports" ("serviceId");
      CREATE INDEX IF NOT EXISTS "IDX_service_reports_reporterId" ON "service_reports" ("reporterId");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "service_reports";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "service_favorites";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "service_listings";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "service_report_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "service_report_reason_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "service_verification_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "service_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "service_category_enum";`);

    await queryRunner.query(`DROP TABLE IF EXISTS "business_reports";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "business_favorites";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "business_services";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "business_images";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "businesses";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "business_report_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "business_report_reason_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "business_verification_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "business_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "business_category_enum";`);
  }
}

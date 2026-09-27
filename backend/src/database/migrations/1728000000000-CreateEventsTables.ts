import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateEventsTables1728000000000 implements MigrationInterface {
  name = 'CreateEventsTables1728000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Ensure PostGIS is enabled
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS postgis;`);

    // 2. Create Enums
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "event_category_enum" AS ENUM (
          'social',
          'cultural',
          'sports',
          'workshop',
          'volunteering',
          'neighborhood',
          'other'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "event_status_enum" AS ENUM ('active', 'cancelled', 'completed');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "event_rsvp_status_enum" AS ENUM ('going', 'interested', 'not_going');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 3. Extend existing Enums for Safety & Notifications
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE "safety_report_target_type_enum" ADD VALUE IF NOT EXISTS 'event';
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE "notification_type_enum" ADD VALUE IF NOT EXISTS 'EVENT_RSVP';
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE "notification_type_enum" ADD VALUE IF NOT EXISTS 'EVENT_CANCELLED';
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE "notification_type_enum" ADD VALUE IF NOT EXISTS 'EVENT_UPDATE';
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 4. Create events table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "events" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "creatorId" uuid NOT NULL,
        "communityId" uuid,
        "title" character varying(150) NOT NULL,
        "description" text NOT NULL,
        "category" "event_category_enum" NOT NULL DEFAULT 'neighborhood',
        "status" "event_status_enum" NOT NULL DEFAULT 'active',
        "startAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "endAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "timezone" character varying(50) NOT NULL DEFAULT 'Asia/Kolkata',
        "venue" character varying(200) NOT NULL,
        "address" text NOT NULL,
        "locality" character varying(150),
        "city" character varying(100),
        "state" character varying(100),
        "countryCode" character varying(5) NOT NULL DEFAULT 'IN',
        "location" geography(Point, 4326),
        "coverImageUrl" character varying(500),
        "participantCount" integer NOT NULL DEFAULT 0,
        "cancelledAt" TIMESTAMP WITH TIME ZONE,
        "cancellationReason" text,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deletedAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_events_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_events_creator" FOREIGN KEY ("creatorId") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_events_community" FOREIGN KEY ("communityId") REFERENCES "communities"("id") ON DELETE SET NULL
      );
    `);

    // 5. Create event_rsvps table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "event_rsvps" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "eventId" uuid NOT NULL,
        "userId" uuid NOT NULL,
        "status" "event_rsvp_status_enum" NOT NULL DEFAULT 'going',
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_event_rsvps_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_event_rsvps_event_user" UNIQUE ("eventId", "userId"),
        CONSTRAINT "FK_event_rsvps_event" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_event_rsvps_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // 6. Create Indexes
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_events_status_startAt"
      ON "events" ("status", "startAt");
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_events_locality_startAt"
      ON "events" ("locality", "startAt");
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_events_community_startAt"
      ON "events" ("communityId", "startAt")
      WHERE "communityId" IS NOT NULL;
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_events_creator_createdAt"
      ON "events" ("creatorId", "createdAt");
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_events_category_startAt"
      ON "events" ("category", "startAt");
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_events_location_gist"
      ON "events" USING GIST ("location")
      WHERE "deletedAt" IS NULL;
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_event_rsvps_event_status"
      ON "event_rsvps" ("eventId", "status");
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_event_rsvps_user_createdAt"
      ON "event_rsvps" ("userId", "createdAt");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_event_rsvps_user_createdAt";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_event_rsvps_event_status";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_events_location_gist";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_events_category_startAt";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_events_creator_createdAt";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_events_community_startAt";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_events_locality_startAt";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_events_status_startAt";`);

    await queryRunner.query(`DROP TABLE IF EXISTS "event_rsvps";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "events";`);

    await queryRunner.query(`DROP TYPE IF EXISTS "event_rsvp_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "event_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "event_category_enum";`);
  }
}

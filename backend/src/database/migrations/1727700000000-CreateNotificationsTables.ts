import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateNotificationsTables1727700000000 implements MigrationInterface {
  name = 'CreateNotificationsTables1727700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create Enums
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "notification_type_enum" AS ENUM (
          'MESSAGE_RECEIVED',
          'POST_LIKED',
          'POST_COMMENTED',
          'COMMENT_REPLIED',
          'COMMUNITY_MEMBERSHIP',
          'MARKETPLACE_ACTIVITY',
          'BUSINESS_ACTIVITY',
          'COMMUNITY_ANNOUNCEMENT',
          'SYSTEM'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "notification_category_enum" AS ENUM (
          'MESSAGES',
          'SOCIAL',
          'COMMUNITY',
          'MARKETPLACE',
          'BUSINESS',
          'SYSTEM'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "device_platform_enum" AS ENUM ('android', 'ios', 'web');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 2. Create notification_preferences table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "notification_preferences" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "userId" uuid NOT NULL,
        "messagesEnabled" boolean NOT NULL DEFAULT true,
        "socialEnabled" boolean NOT NULL DEFAULT true,
        "communityEnabled" boolean NOT NULL DEFAULT true,
        "marketplaceEnabled" boolean NOT NULL DEFAULT true,
        "businessEnabled" boolean NOT NULL DEFAULT true,
        "systemEnabled" boolean NOT NULL DEFAULT true,
        "pushEnabled" boolean NOT NULL DEFAULT true,
        "emailEnabled" boolean NOT NULL DEFAULT false,
        "smsEnabled" boolean NOT NULL DEFAULT false,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_notification_preferences_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_notification_preferences_userId" UNIQUE ("userId"),
        CONSTRAINT "FK_notification_preferences_userId" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    // 3. Create device_tokens table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "device_tokens" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "userId" uuid NOT NULL,
        "token" text NOT NULL,
        "platform" "device_platform_enum" NOT NULL DEFAULT 'android',
        "deviceId" varchar(255),
        "isActive" boolean NOT NULL DEFAULT true,
        "lastUsedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_device_tokens_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_device_tokens_token" UNIQUE ("token"),
        CONSTRAINT "FK_device_tokens_userId" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_device_tokens_userId" ON "device_tokens" ("userId");
    `);

    // 4. Create notifications table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "notifications" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "recipientId" uuid NOT NULL,
        "senderId" uuid,
        "type" "notification_type_enum" NOT NULL,
        "category" "notification_category_enum" NOT NULL,
        "title" character varying(255) NOT NULL,
        "body" text NOT NULL,
        "data" jsonb NOT NULL DEFAULT '{}'::jsonb,
        "deepLink" character varying(500),
        "isRead" boolean NOT NULL DEFAULT false,
        "readAt" TIMESTAMP WITH TIME ZONE,
        "deduplicationKey" character varying(255),
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deletedAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_notifications_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_notifications_recipientId" FOREIGN KEY ("recipientId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_notifications_senderId" FOREIGN KEY ("senderId")
          REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_notifications_recipientId" ON "notifications" ("recipientId");
      CREATE INDEX IF NOT EXISTS "IDX_notifications_senderId" ON "notifications" ("senderId");
      CREATE INDEX IF NOT EXISTS "IDX_notifications_recipient_createdAt" ON "notifications" ("recipientId", "createdAt" DESC);
      CREATE INDEX IF NOT EXISTS "IDX_notifications_recipient_isRead" ON "notifications" ("recipientId", "isRead");
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_notifications_deduplicationKey" ON "notifications" ("deduplicationKey") WHERE "deduplicationKey" IS NOT NULL;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "notifications";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "device_tokens";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "notification_preferences";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "device_platform_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "notification_category_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "notification_type_enum";`);
  }
}

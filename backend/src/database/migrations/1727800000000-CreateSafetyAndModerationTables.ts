import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateSafetyAndModerationTables1727800000000 implements MigrationInterface {
  name = 'CreateSafetyAndModerationTables1727800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. User Role Enum & Column
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "user_role_enum" AS ENUM ('user', 'moderator', 'admin');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "role" "user_role_enum" NOT NULL DEFAULT 'user';
      EXCEPTION
        WHEN duplicate_column THEN null;
      END $$;
    `);

    // 2. Safety Enums
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "safety_report_target_type_enum" AS ENUM (
          'user',
          'post',
          'comment',
          'listing',
          'business',
          'service',
          'conversation',
          'message'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "safety_report_reason_enum" AS ENUM (
          'spam',
          'harassment',
          'hate_or_abuse',
          'threats',
          'scam_or_fraud',
          'sexual_content',
          'violence',
          'illegal_activity',
          'misinformation',
          'impersonation',
          'privacy_violation',
          'inappropriate_content',
          'other'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "safety_moderation_status_enum" AS ENUM (
          'pending',
          'reviewing',
          'actioned',
          'dismissed',
          'duplicate'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 3. Create safety_reports Table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "safety_reports" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "reporterId" uuid NOT NULL,
        "targetType" "safety_report_target_type_enum" NOT NULL,
        "targetId" uuid NOT NULL,
        "secondaryId" uuid,
        "reason" "safety_report_reason_enum" NOT NULL,
        "details" character varying(2000),
        "status" "safety_moderation_status_enum" NOT NULL DEFAULT 'pending',
        "domainReportId" uuid,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_safety_reports_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_safety_reports_reporterId" FOREIGN KEY ("reporterId")
          REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_safety_reports_reporterId" ON "safety_reports" ("reporterId");
      CREATE INDEX IF NOT EXISTS "IDX_safety_reports_target" ON "safety_reports" ("targetType", "targetId");
      CREATE INDEX IF NOT EXISTS "IDX_safety_reports_status" ON "safety_reports" ("status");
      CREATE INDEX IF NOT EXISTS "IDX_safety_reports_createdAt" ON "safety_reports" ("createdAt");
    `);

    // 4. Create moderation_audit_logs Table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "moderation_audit_logs" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "actorId" uuid NOT NULL,
        "action" character varying(50) NOT NULL,
        "targetType" character varying(50) NOT NULL,
        "targetId" character varying(100) NOT NULL,
        "reportId" uuid,
        "reason" character varying(255),
        "metadata" jsonb,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_moderation_audit_logs_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_moderation_audit_logs_actorId" FOREIGN KEY ("actorId")
          REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_moderation_audit_logs_actorId" ON "moderation_audit_logs" ("actorId");
      CREATE INDEX IF NOT EXISTS "IDX_moderation_audit_logs_target" ON "moderation_audit_logs" ("targetType", "targetId");
      CREATE INDEX IF NOT EXISTS "IDX_moderation_audit_logs_action" ON "moderation_audit_logs" ("action");
      CREATE INDEX IF NOT EXISTS "IDX_moderation_audit_logs_createdAt" ON "moderation_audit_logs" ("createdAt");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "moderation_audit_logs";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "safety_reports";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "safety_moderation_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "safety_report_reason_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "safety_report_target_type_enum";`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "role";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "user_role_enum";`);
  }
}

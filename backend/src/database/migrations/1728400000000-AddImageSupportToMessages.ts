import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddImageSupportToMessages1728400000000 implements MigrationInterface {
  name = 'AddImageSupportToMessages1728400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TYPE "message_type_enum" ADD VALUE IF NOT EXISTS 'IMAGE';
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "mediaUrl" text;
      ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "mediaThumbnailUrl" text;
      ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "mediaWidth" integer;
      ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "mediaHeight" integer;
      ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "mediaSize" integer;
      ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "mediaMimeType" character varying(50);
      ALTER TABLE "messages" ALTER COLUMN "content" DROP NOT NULL;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "messages" DROP COLUMN IF EXISTS "mediaMimeType";
      ALTER TABLE "messages" DROP COLUMN IF EXISTS "mediaSize";
      ALTER TABLE "messages" DROP COLUMN IF EXISTS "mediaHeight";
      ALTER TABLE "messages" DROP COLUMN IF EXISTS "mediaWidth";
      ALTER TABLE "messages" DROP COLUMN IF EXISTS "mediaThumbnailUrl";
      ALTER TABLE "messages" DROP COLUMN IF EXISTS "mediaUrl";
    `);
  }
}

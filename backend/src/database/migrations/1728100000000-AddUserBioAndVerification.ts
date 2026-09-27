import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUserBioAndVerification1728100000000 implements MigrationInterface {
  name = 'AddUserBioAndVerification1728100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN IF NOT EXISTS "bio" character varying(300),
      ADD COLUMN IF NOT EXISTS "phoneVerified" boolean NOT NULL DEFAULT true;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      DROP COLUMN IF EXISTS "bio",
      DROP COLUMN IF EXISTS "phoneVerified";
    `);
  }
}

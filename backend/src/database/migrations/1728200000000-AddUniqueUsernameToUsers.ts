import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUniqueUsernameToUsers1728200000000 implements MigrationInterface {
  name = 'AddUniqueUsernameToUsers1728200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN IF NOT EXISTS "username" character varying(30);

      CREATE UNIQUE INDEX IF NOT EXISTS "idx_users_username_lower"
      ON "users" (LOWER("username"))
      WHERE "username" IS NOT NULL;

      CREATE INDEX IF NOT EXISTS "idx_users_display_name_lower"
      ON "users" (LOWER("displayName"))
      WHERE "displayName" IS NOT NULL;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS "idx_users_display_name_lower";
      DROP INDEX IF EXISTS "idx_users_username_lower";
      ALTER TABLE "users" DROP COLUMN IF EXISTS "username";
    `);
  }
}

import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateAuthAndUsersTables1727000000000 implements MigrationInterface {
  name = 'CreateAuthAndUsersTables1727000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create enum for user status
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "user_status_enum" AS ENUM ('active', 'suspended', 'deleted');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 2. Create users table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "users" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "phoneNumber" character varying(20) NOT NULL,
        "displayName" character varying(100),
        "avatarUrl" character varying(500),
        "accountStatus" "user_status_enum" NOT NULL DEFAULT 'active',
        "onboardingCompleted" boolean NOT NULL DEFAULT false,
        "countryCode" character varying(5) DEFAULT 'IN',
        "state" character varying(100),
        "district" character varying(100),
        "city" character varying(100),
        "locality" character varying(150),
        "neighborhood" character varying(150),
        "lastLoginAt" TIMESTAMP WITH TIME ZONE,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_users_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_users_phoneNumber" UNIQUE ("phoneNumber")
      );
    `);

    // Indexes for users
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_users_phoneNumber" ON "users" ("phoneNumber");
      CREATE INDEX IF NOT EXISTS "IDX_users_countryCode" ON "users" ("countryCode");
      CREATE INDEX IF NOT EXISTS "IDX_users_state" ON "users" ("state");
      CREATE INDEX IF NOT EXISTS "IDX_users_district" ON "users" ("district");
      CREATE INDEX IF NOT EXISTS "IDX_users_city" ON "users" ("city");
      CREATE INDEX IF NOT EXISTS "IDX_users_locality" ON "users" ("locality");
    `);

    // 3. Create auth_sessions table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "auth_sessions" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "userId" uuid NOT NULL,
        "refreshTokenHash" character varying(64) NOT NULL,
        "deviceInfo" character varying(255),
        "ipAddress" character varying(45),
        "expiresAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "revokedAt" TIMESTAMP WITH TIME ZONE,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_auth_sessions_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_auth_sessions_userId" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    // Indexes for auth_sessions
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_auth_sessions_userId" ON "auth_sessions" ("userId");
      CREATE INDEX IF NOT EXISTS "IDX_auth_sessions_expiresAt" ON "auth_sessions" ("expiresAt");
      CREATE INDEX IF NOT EXISTS "IDX_auth_sessions_revokedAt" ON "auth_sessions" ("revokedAt");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "auth_sessions";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "users";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "user_status_enum";`);
  }
}

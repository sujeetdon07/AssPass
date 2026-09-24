import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateCommunitiesTables1727300000000 implements MigrationInterface {
  name = 'CreateCommunitiesTables1727300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create Enums
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "community_visibility_enum" AS ENUM ('public', 'private');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "community_status_enum" AS ENUM ('active', 'suspended', 'archived');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "community_role_enum" AS ENUM ('owner', 'moderator', 'member');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "community_member_status_enum" AS ENUM ('active', 'pending', 'banned');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 2. Extend report_target_enum if needed
    await queryRunner.query(`
      ALTER TYPE "report_target_enum" ADD VALUE IF NOT EXISTS 'community';
    `);

    // 3. Create communities table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "communities" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" character varying(100) NOT NULL,
        "slug" character varying(150) NOT NULL,
        "description" text NOT NULL,
        "category" character varying(50) NOT NULL DEFAULT 'neighborhood',
        "visibility" "community_visibility_enum" NOT NULL DEFAULT 'public',
        "status" "community_status_enum" NOT NULL DEFAULT 'active',
        "creatorId" uuid NOT NULL,
        "countryCode" character varying(5) NOT NULL DEFAULT 'IN',
        "state" character varying(100),
        "district" character varying(100),
        "city" character varying(100),
        "locality" character varying(150),
        "neighborhood" character varying(150),
        "memberCount" integer NOT NULL DEFAULT 1,
        "postCount" integer NOT NULL DEFAULT 0,
        "coverImageUrl" character varying(500),
        "avatarUrl" character varying(500),
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_communities_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_communities_slug" UNIQUE ("slug"),
        CONSTRAINT "FK_communities_creatorId" FOREIGN KEY ("creatorId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_communities_slug" ON "communities" ("slug");
      CREATE INDEX IF NOT EXISTS "IDX_communities_creatorId" ON "communities" ("creatorId");
      CREATE INDEX IF NOT EXISTS "IDX_communities_category" ON "communities" ("category");
      CREATE INDEX IF NOT EXISTS "IDX_communities_visibility" ON "communities" ("visibility");
      CREATE INDEX IF NOT EXISTS "IDX_communities_status" ON "communities" ("status");
      CREATE INDEX IF NOT EXISTS "IDX_communities_city_locality" ON "communities" ("city", "locality");
      CREATE INDEX IF NOT EXISTS "IDX_communities_createdAt" ON "communities" ("createdAt");
    `);

    // 4. Create community_members table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "community_members" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "communityId" uuid NOT NULL,
        "userId" uuid NOT NULL,
        "role" "community_role_enum" NOT NULL DEFAULT 'member',
        "status" "community_member_status_enum" NOT NULL DEFAULT 'active',
        "joinedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_community_members_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_community_members_community_user" UNIQUE ("communityId", "userId"),
        CONSTRAINT "FK_community_members_communityId" FOREIGN KEY ("communityId")
          REFERENCES "communities"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_community_members_userId" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_community_members_communityId" ON "community_members" ("communityId");
      CREATE INDEX IF NOT EXISTS "IDX_community_members_userId" ON "community_members" ("userId");
      CREATE INDEX IF NOT EXISTS "IDX_community_members_role" ON "community_members" ("role");
      CREATE INDEX IF NOT EXISTS "IDX_community_members_status" ON "community_members" ("status");
    `);

    // 5. Extend posts table with communityId
    await queryRunner.query(`
      ALTER TABLE "posts"
      ADD COLUMN IF NOT EXISTS "communityId" uuid;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TABLE "posts"
        ADD CONSTRAINT "FK_posts_communityId" FOREIGN KEY ("communityId")
          REFERENCES "communities"("id") ON DELETE SET NULL ON UPDATE NO ACTION;
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_posts_communityId" ON "posts" ("communityId");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_posts_communityId";`);
    await queryRunner.query(`ALTER TABLE "posts" DROP CONSTRAINT IF EXISTS "FK_posts_communityId";`);
    await queryRunner.query(`ALTER TABLE "posts" DROP COLUMN IF EXISTS "communityId";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "community_members";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "communities";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "community_member_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "community_role_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "community_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "community_visibility_enum";`);
  }
}

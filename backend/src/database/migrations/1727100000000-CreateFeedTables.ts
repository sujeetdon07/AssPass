import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateFeedTables1727100000000 implements MigrationInterface {
  name = 'CreateFeedTables1727100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create Enums
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "post_category_enum" AS ENUM ('general', 'announcement', 'question', 'recommendation', 'alert');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "reaction_type_enum" AS ENUM ('like');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "report_target_enum" AS ENUM ('post', 'comment');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "report_reason_enum" AS ENUM ('spam', 'harassment', 'inappropriate', 'misleading', 'illegal_content', 'other');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "report_status_enum" AS ENUM ('pending', 'reviewed', 'dismissed');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // 2. Create posts table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "posts" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "authorId" uuid NOT NULL,
        "content" text NOT NULL,
        "category" "post_category_enum" NOT NULL DEFAULT 'general',
        "countryCode" character varying(5) NOT NULL DEFAULT 'IN',
        "state" character varying(100),
        "district" character varying(100),
        "city" character varying(100),
        "locality" character varying(150),
        "neighborhood" character varying(150),
        "likeCount" integer NOT NULL DEFAULT 0,
        "commentCount" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deletedAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_posts_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_posts_authorId" FOREIGN KEY ("authorId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_posts_authorId" ON "posts" ("authorId");
      CREATE INDEX IF NOT EXISTS "IDX_posts_createdAt" ON "posts" ("createdAt");
      CREATE INDEX IF NOT EXISTS "IDX_posts_deletedAt" ON "posts" ("deletedAt");
      CREATE INDEX IF NOT EXISTS "IDX_posts_city_locality" ON "posts" ("city", "locality");
      CREATE INDEX IF NOT EXISTS "IDX_posts_category" ON "posts" ("category");
    `);

    // 3. Create post_reactions table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "post_reactions" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "postId" uuid NOT NULL,
        "userId" uuid NOT NULL,
        "reactionType" "reaction_type_enum" NOT NULL DEFAULT 'like',
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_post_reactions_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_post_reactions_post_user_reaction" UNIQUE ("postId", "userId", "reactionType"),
        CONSTRAINT "FK_post_reactions_postId" FOREIGN KEY ("postId")
          REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_post_reactions_userId" FOREIGN KEY ("userId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_post_reactions_postId" ON "post_reactions" ("postId");
      CREATE INDEX IF NOT EXISTS "IDX_post_reactions_userId" ON "post_reactions" ("userId");
    `);

    // 4. Create comments table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "comments" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "postId" uuid NOT NULL,
        "authorId" uuid NOT NULL,
        "content" text NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "deletedAt" TIMESTAMP WITH TIME ZONE,
        CONSTRAINT "PK_comments_id" PRIMARY KEY ("id"),
        CONSTRAINT "FK_comments_postId" FOREIGN KEY ("postId")
          REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "FK_comments_authorId" FOREIGN KEY ("authorId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_comments_postId_createdAt" ON "comments" ("postId", "createdAt");
      CREATE INDEX IF NOT EXISTS "IDX_comments_authorId" ON "comments" ("authorId");
      CREATE INDEX IF NOT EXISTS "IDX_comments_deletedAt" ON "comments" ("deletedAt");
    `);

    // 5. Create reports table
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "reports" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "reporterId" uuid NOT NULL,
        "targetType" "report_target_enum" NOT NULL,
        "targetId" uuid NOT NULL,
        "reason" "report_reason_enum" NOT NULL,
        "details" character varying(500),
        "status" "report_status_enum" NOT NULL DEFAULT 'pending',
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_reports_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_reports_reporter_target" UNIQUE ("reporterId", "targetType", "targetId"),
        CONSTRAINT "FK_reports_reporterId" FOREIGN KEY ("reporterId")
          REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
      );
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_reports_reporterId" ON "reports" ("reporterId");
      CREATE INDEX IF NOT EXISTS "IDX_reports_target" ON "reports" ("targetType", "targetId");
      CREATE INDEX IF NOT EXISTS "IDX_reports_status" ON "reports" ("status");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "reports";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "comments";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "post_reactions";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "posts";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "report_status_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "report_reason_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "report_target_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "reaction_type_enum";`);
    await queryRunner.query(`DROP TYPE IF EXISTS "post_category_enum";`);
  }
}

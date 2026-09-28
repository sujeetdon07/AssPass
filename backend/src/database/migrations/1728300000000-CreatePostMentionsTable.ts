import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePostMentionsTable1728300000000 implements MigrationInterface {
  name = 'CreatePostMentionsTable1728300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "post_mentions" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "postId" uuid NOT NULL REFERENCES "posts"("id") ON DELETE CASCADE,
        "mentionedUserId" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
        "start" integer NOT NULL,
        "length" integer NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_post_mentions_post_user_range" UNIQUE ("postId", "mentionedUserId", "start", "length")
      );

      CREATE INDEX IF NOT EXISTS "IDX_post_mentions_postId" ON "post_mentions" ("postId");
      CREATE INDEX IF NOT EXISTS "IDX_post_mentions_mentionedUserId" ON "post_mentions" ("mentionedUserId");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS "post_mentions";
    `);
  }
}

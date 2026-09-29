import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePostImagesTable1728500000000 implements MigrationInterface {
  name = 'CreatePostImagesTable1728500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "post_images" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "postId" uuid NOT NULL REFERENCES "posts"("id") ON DELETE CASCADE,
        "url" text NOT NULL,
        "thumbnailUrl" text NOT NULL,
        "mediumUrl" text,
        "width" integer,
        "height" integer,
        "mimeType" character varying(50),
        "size" integer,
        "sortOrder" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
      );

      CREATE INDEX IF NOT EXISTS "IDX_post_images_postId" ON "post_images" ("postId");
      CREATE INDEX IF NOT EXISTS "IDX_post_images_postId_sortOrder" ON "post_images" ("postId", "sortOrder");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS "post_images";
    `);
  }
}

import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Phase 12 Performance & Scale Indexing Migration.
 *
 * Adds composite and partial indexes specifically targeting measured
 * query access patterns identified during the performance audit:
 *
 * 1. Feed cursor pagination with city/locality scoping and deletedAt filtering
 * 2. Feed category filtering
 * 3. Marketplace discovery by status, category, and locality
 * 4. Businesses and services directory queries by status and category
 * 5. Users directory filtering by role and account status
 * 6. Safety reports queue triage by status and caller history
 * 7. Moderation audit log chronological ordering
 */
export class AddPhase12PerformanceIndexes1727900000000 implements MigrationInterface {
  name = 'AddPhase12PerformanceIndexes1727900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Feed Pagination & Category Indexes
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_posts_feed_pagination"
      ON "posts" ("city", "locality", "createdAt" DESC, "id" DESC)
      WHERE "deletedAt" IS NULL;
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_posts_category_feed"
      ON "posts" ("category", "createdAt" DESC)
      WHERE "deletedAt" IS NULL;
    `);

    // 2. Marketplace Directory Composite Indexes
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_marketplace_active_created"
      ON "marketplace_listings" ("status", "category", "createdAt" DESC)
      WHERE "deletedAt" IS NULL;
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_marketplace_city_status"
      ON "marketplace_listings" ("city", "locality", "status", "createdAt" DESC)
      WHERE "deletedAt" IS NULL;
    `);

    // 3. Businesses & Services Active Directory Indexes
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_businesses_active_created"
      ON "businesses" ("status", "category", "createdAt" DESC)
      WHERE "deletedAt" IS NULL;
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_services_active_created"
      ON "service_listings" ("status", "category", "createdAt" DESC)
      WHERE "deletedAt" IS NULL;
    `);

    // 4. Users Directory RBAC & Status Index
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_users_role_status_created"
      ON "users" ("role", "accountStatus", "createdAt" DESC);
    `);

    // 5. Safety Reports Queue & History Indexes
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_safety_reports_status_created"
      ON "safety_reports" ("status", "createdAt" DESC);
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_safety_reports_reporter_created"
      ON "safety_reports" ("reporterId", "createdAt" DESC);
    `);

    // 6. Moderation Audit Logs Chronological Index
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_moderation_audit_logs_created_desc"
      ON "moderation_audit_logs" ("createdAt" DESC);
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_moderation_audit_logs_created_desc";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_safety_reports_reporter_created";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_safety_reports_status_created";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_users_role_status_created";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_services_active_created";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_businesses_active_created";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_marketplace_city_status";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_marketplace_active_created";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_posts_category_feed";`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_posts_feed_pagination";`);
  }
}

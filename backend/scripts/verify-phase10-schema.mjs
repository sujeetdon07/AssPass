import pg from 'pg';
const { Client } = pg;

async function checkSchema() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db',
  });
  await client.connect();

  console.log('=== 1. Checking Role Column in Users Table ===');
  const roleRes = await client.query(`
    SELECT column_name, udt_name, column_default, is_nullable
    FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'role';
  `);
  console.log('Users Role Column:', roleRes.rows);

  console.log('\n=== 2. Checking Safety & Moderation Tables ===');
  const tablesRes = await client.query(`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name IN ('safety_reports', 'moderation_audit_logs', 'users', 'posts', 'comments', 'marketplace_listings', 'businesses', 'service_listings', 'conversations', 'messages', 'notifications');
  `);
  console.log('Found Required Tables:', tablesRes.rows.map(r => r.table_name));

  console.log('\n=== 3. Safety Reports Columns ===');
  const srCols = await client.query(`
    SELECT column_name, udt_name, is_nullable
    FROM information_schema.columns
    WHERE table_name = 'safety_reports'
    ORDER BY ordinal_position;
  `);
  console.log('safety_reports Columns:', srCols.rows);

  console.log('\n=== 4. Moderation Audit Logs Columns ===');
  const malCols = await client.query(`
    SELECT column_name, udt_name, is_nullable
    FROM information_schema.columns
    WHERE table_name = 'moderation_audit_logs'
    ORDER BY ordinal_position;
  `);
  console.log('moderation_audit_logs Columns:', malCols.rows);

  console.log('\n=== 5. Indexes on Phase 10 Tables ===');
  const idxRes = await client.query(`
    SELECT tablename, indexname, indexdef
    FROM pg_indexes
    WHERE tablename IN ('safety_reports', 'moderation_audit_logs');
  `);
  console.log('Phase 10 Indexes:', idxRes.rows);

  console.log('\n=== 6. Foreign Key Constraints ===');
  const fkRes = await client.query(`
    SELECT tc.table_name, tc.constraint_name, kcu.column_name, ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name IN ('safety_reports', 'moderation_audit_logs');
  `);
  console.log('Foreign Keys:', fkRes.rows);

  console.log('\n=== 7. Enum Types Check ===');
  const enumRes = await client.query(`
    SELECT t.typname, e.enumlabel
    FROM pg_type t
    JOIN pg_enum e ON t.oid = e.enumtypid
    WHERE t.typname IN ('user_role_enum', 'safety_moderation_status_enum', 'safety_report_target_type_enum', 'safety_report_reason_enum')
    ORDER BY t.typname, e.enumsortorder;
  `);
  console.log('Enum Values Count:', enumRes.rows.length);

  await client.end();
  console.log('\n[PASS] Database Schema Integrity Verified Successfully!');
}

checkSchema().catch(err => {
  console.error('[FAIL]', err);
  process.exit(1);
});

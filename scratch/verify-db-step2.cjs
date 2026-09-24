const { Client } = require('pg');
const fs = require('fs');

async function run() {
  const client = new Client({
    host: 'localhost',
    port: 5432,
    user: 'postgres',
    password: 'password',
    database: 'aaspaas',
  });
  await client.connect();

  console.log('=== 1. PostGIS Extension Check ===');
  const extRes = await client.query("SELECT extname, extversion FROM pg_extension WHERE extname = 'postgis'");
  console.log('PostGIS Extension:', extRes.rows);

  console.log('\n=== 2. Required Phase 7 Tables Check ===');
  const tables = [
    'businesses',
    'business_images',
    'business_services',
    'business_favorites',
    'business_reports',
    'service_listings',
    'service_favorites',
    'service_reports',
  ];
  const tableRes = await client.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ANY($1)",
    [tables]
  );
  console.log(`Found Tables (${tableRes.rows.length}/${tables.length}):`, tableRes.rows.map((r) => r.table_name));

  console.log('\n=== 3. PostGIS Geometry Location Columns ===');
  const geomRes = await client.query(
    'SELECT f_table_name, f_geometry_column, coord_dimension, srid, type FROM geometry_columns WHERE f_table_name = ANY($1)',
    [tables]
  );
  console.log('Geometry Columns:', geomRes.rows);

  console.log('\n=== 4. GiST Indexes on Location ===');
  const gistRes = await client.query(
    "SELECT tablename, indexname, indexdef FROM pg_indexes WHERE tablename = ANY($1) AND indexdef LIKE '%gist%'",
    [tables]
  );
  console.log('GiST Indexes:', gistRes.rows);

  console.log('\n=== 5. Unique Constraints ===');
  const uniqRes = await client.query(
    `SELECT tc.table_name, tc.constraint_name, kcu.column_name 
     FROM information_schema.table_constraints tc 
     JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name 
     WHERE tc.constraint_type = 'UNIQUE' AND tc.table_name = ANY($1)`,
    [tables]
  );
  console.log('Unique Constraints:', uniqRes.rows);

  console.log('\n=== 6. Foreign Keys & Cascade Deletes ===');
  const fkRes = await client.query(
    `SELECT tc.table_name, kcu.column_name, ccu.table_name AS foreign_table_name, rc.delete_rule 
     FROM information_schema.table_constraints AS tc 
     JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name 
     JOIN information_schema.referential_constraints AS rc ON tc.constraint_name = rc.constraint_name 
     JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name 
     WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name = ANY($1)`,
    [tables]
  );
  console.log('Foreign Keys & Cascade Rules:');
  for (const row of fkRes.rows) {
    console.log(`  - ${row.table_name}.${row.column_name} -> ${row.foreign_table_name} [DELETE: ${row.delete_rule}]`);
  }

  console.log('\n=== 7. Migration File Check ===');
  const migrationPath = 'backend/src/migrations/1727500000000-CreateBusinessesAndServicesTables.ts';
  const exists = fs.existsSync(migrationPath);
  console.log('Migration file exists:', exists, `(${migrationPath})`);
  if (exists) {
    const content = fs.readFileSync(migrationPath, 'utf8');
    console.log('Migration contains CreateBusinessesAndServicesTables:', content.includes('CreateBusinessesAndServicesTables1727500000000'));
  }

  await client.end();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

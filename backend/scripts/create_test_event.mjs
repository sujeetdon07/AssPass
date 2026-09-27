import pg from '../node_modules/pg/lib/index.js';
const { Client } = pg;

const client = new Client({
  connectionString: 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db',
});

async function main() {
  await client.connect();
  const userRes = await client.query('SELECT id, locality, city FROM users LIMIT 1');
  if (userRes.rows.length === 0) {
    console.error('No users found in database');
    process.exit(1);
  }
  const user = userRes.rows[0];
  console.log('Using user:', user);

  const startAt = new Date(Date.now() + 24 * 3600 * 1000);
  const endAt = new Date(Date.now() + 26 * 3600 * 1000);

  const insertRes = await client.query(
    `INSERT INTO events (
      "creatorId", title, description, category, status, "startAt", "endAt",
      timezone, venue, address, locality, city, state, "participantCount"
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
    ) RETURNING *`,
    [
      user.id,
      'Indiranagar Morning 5K Community Run & Breakfast',
      'Join us for an energetic morning 5K run followed by breakfast and neighborhood networking!',
      'sports',
      'active',
      startAt,
      endAt,
      'Asia/Kolkata',
      'Indiranagar Club Ground',
      '100 Feet Road, Indiranagar',
      user.locality || 'Indiranagar',
      user.city || 'Bengaluru',
      'Karnataka',
      3,
    ]
  );

  console.log('Created event:', insertRes.rows[0].id, insertRes.rows[0].title);
  await client.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

import pg from 'pg';
const { Client } = pg;

const client = new Client({
  connectionString: 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db',
});

async function seed() {
  await client.connect();

  const users = [
    { phone: '+919999000001', name: 'Platform Admin', role: 'admin' },
    { phone: '+919999000002', name: 'Duty Moderator', role: 'moderator' },
    { phone: '+919999000003', name: 'Standard Citizen', role: 'user' },
  ];

  for (const u of users) {
    const res = await client.query('SELECT id, role FROM users WHERE "phoneNumber" = $1', [u.phone]);
    if (res.rows.length === 0) {
      await client.query(
        'INSERT INTO users ("phoneNumber", "displayName", role, "accountStatus", "onboardingCompleted", "countryCode") VALUES ($1, $2, $3, $4, $5, $6)',
        [u.phone, u.name, u.role, 'active', true, 'IN']
      );
      console.log(`Created ${u.role}: ${u.name} (${u.phone})`);
    } else {
      await client.query(
        'UPDATE users SET role = $1, "accountStatus" = $2, "displayName" = $3 WHERE id = $4',
        [u.role, 'active', u.name, res.rows[0].id]
      );
      console.log(`Updated ${u.role}: ${u.name} (${u.phone})`);
    }
  }

  await client.end();
}

seed().catch(console.error);

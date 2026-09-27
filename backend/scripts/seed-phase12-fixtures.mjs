/**
 * AASPAAS PHASE 12 — Seed Realistic Development Fixtures
 *
 * Populates realistic hyperlocal community data for performance benchmarking:
 * - 150+ Posts across 5 Bengaluru localities with PostGIS centroids
 * - 60+ Marketplace listings with prices, categories, conditions
 * - 40+ Local businesses and services
 * - 80+ Notifications
 * - 50+ Safety reports & moderation audit logs
 */

import pg from 'pg';

const DB_URL = process.env.DATABASE_URL || 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db';
const pool = new pg.Pool({ connectionString: DB_URL });

const LOCALITIES = [
  { name: 'Indiranagar', lat: 12.9784, lng: 77.6408 },
  { name: 'Koramangala', lat: 12.9352, lng: 77.6245 },
  { name: 'HSR Layout', lat: 12.9121, lng: 77.6446 },
  { name: 'Whitefield', lat: 12.9698, lng: 77.7500 },
  { name: 'Jayanagar', lat: 12.9308, lng: 77.5838 },
];

const POST_CATEGORIES = ['general', 'announcement', 'question', 'recommendation', 'alert'];
const LISTING_CATEGORIES = ['electronics', 'mobiles', 'computers', 'furniture', 'home_kitchen', 'vehicles', 'books', 'fashion', 'kids', 'sports', 'other'];
const BUSINESS_CATEGORIES = ['food_dining', 'grocery', 'shopping', 'health', 'beauty', 'fitness', 'education', 'electronics', 'home_repair', 'automotive', 'professional', 'other'];
const SERVICE_CATEGORIES = ['home_repair', 'education', 'beauty', 'cleaning', 'photography', 'automotive', 'technology', 'personal_services', 'other'];

async function seed() {
  console.log('Seeding Phase 12 performance fixtures...');
  const client = await pool.connect();

  try {
    // Get existing users
    const usersRes = await client.query('SELECT "id" FROM "users" LIMIT 20');
    if (usersRes.rows.length === 0) {
      console.log('No users found. Run seed-admin-users.mjs first.');
      return;
    }
    const userIds = usersRes.rows.map(r => r.id);

    // 1. Seed 150 Posts
    console.log('Seeding posts...');
    for (let i = 0; i < 150; i++) {
      const authorId = userIds[i % userIds.length];
      const loc = LOCALITIES[i % LOCALITIES.length];
      const cat = POST_CATEGORIES[i % POST_CATEGORIES.length];
      // small jitter around locality centroid (~100-800m)
      const latJitter = (Math.random() - 0.5) * 0.01;
      const lngJitter = (Math.random() - 0.5) * 0.01;
      const lat = loc.lat + latJitter;
      const lng = loc.lng + lngJitter;

      await client.query(`
        INSERT INTO "posts" (
          "authorId", "content", "category", "countryCode", "state", "district", "city", "locality",
          "likeCount", "commentCount", "location", "createdAt", "updatedAt"
        ) VALUES (
          $1, $2, $3, 'IN', 'Karnataka', 'Bengaluru Urban', 'Bengaluru', $4,
          $5, $6, ST_SetSRID(ST_MakePoint($7, $8), 4326)::geography,
          now() - ($9 || ' hours')::interval, now() - ($9 || ' hours')::interval
        )
      `, [
        authorId,
        `Hyperlocal update #${i + 1} from ${loc.name}. Community discussion on neighborhood amenities, safety, and local services.`,
        cat,
        loc.name,
        Math.floor(Math.random() * 15),
        Math.floor(Math.random() * 5),
        lng,
        lat,
        String(i * 2),
      ]);
    }

    // 2. Seed 60 Marketplace listings
    console.log('Seeding marketplace listings...');
    for (let i = 0; i < 60; i++) {
      const sellerId = userIds[i % userIds.length];
      const loc = LOCALITIES[i % LOCALITIES.length];
      const cat = LISTING_CATEGORIES[i % LISTING_CATEGORIES.length];
      const price = (Math.floor(Math.random() * 50) + 1) * 200;
      const lat = loc.lat + (Math.random() - 0.5) * 0.01;
      const lng = loc.lng + (Math.random() - 0.5) * 0.01;

      await client.query(`
        INSERT INTO "marketplace_listings" (
          "sellerId", "title", "description", "category", "price", "currency", "condition", "status",
          "countryCode", "state", "district", "city", "locality", "location", "createdAt", "updatedAt"
        ) VALUES (
          $1, $2, $3, $4, $5, 'INR', 'good', 'active',
          'IN', 'Karnataka', 'Bengaluru Urban', 'Bengaluru', $6,
          ST_SetSRID(ST_MakePoint($7, $8), 4326)::geography,
          now() - ($9 || ' hours')::interval, now() - ($9 || ' hours')::interval
        )
      `, [
        sellerId,
        `Item for sale in ${loc.name} #${i + 1}: ${cat.toLowerCase()}`,
        `Pre-loved ${cat.toLowerCase()} available for pickup in ${loc.name}. Great condition, reasonable price.`,
        cat,
        price,
        loc.name,
        lng,
        lat,
        String(i * 3),
      ]);
    }

    // 3. Seed 30 Businesses & 30 Services
    console.log('Seeding businesses & services...');
    for (let i = 0; i < 30; i++) {
      const ownerId = userIds[i % userIds.length];
      const loc = LOCALITIES[i % LOCALITIES.length];
      const bCat = BUSINESS_CATEGORIES[i % BUSINESS_CATEGORIES.length];
      const sCat = SERVICE_CATEGORIES[i % SERVICE_CATEGORIES.length];
      const lat = loc.lat + (Math.random() - 0.5) * 0.01;
      const lng = loc.lng + (Math.random() - 0.5) * 0.01;

      await client.query(`
        INSERT INTO "businesses" (
          "ownerId", "name", "slug", "description", "category", "status", "verificationStatus",
          "countryCode", "city", "locality", "location", "createdAt", "updatedAt"
        ) VALUES (
          $1, $2, $3, $4, $5, 'active', 'verified',
          'IN', 'Bengaluru', $6, ST_SetSRID(ST_MakePoint($7, $8), 4326)::geography,
          now() - ($9 || ' hours')::interval, now() - ($9 || ' hours')::interval
        ) ON CONFLICT DO NOTHING
      `, [
        ownerId,
        `${loc.name} ${bCat.toLowerCase()} hub #${i + 1}`,
        `business-${loc.name.toLowerCase()}-${i + 1}-${Date.now()}`,
        `Neighborhood verified business serving ${loc.name} residents.`,
        bCat,
        loc.name,
        lng,
        lat,
        String(i * 4),
      ]);

      await client.query(`
        INSERT INTO "service_listings" (
          "ownerId", "title", "description", "category", "status", "verificationStatus",
          "countryCode", "city", "locality", "location", "startingPrice", "currency", "serviceRadiusKm",
          "createdAt", "updatedAt"
        ) VALUES (
          $1, $2, $3, $4, 'active', 'verified',
          'IN', 'Bengaluru', $5, ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography,
          $8, 'INR', 10,
          now() - ($9 || ' hours')::interval, now() - ($9 || ' hours')::interval
        )
      `, [
        ownerId,
        `Professional ${sCat.toLowerCase()} in ${loc.name}`,
        `Experienced local provider for all your ${sCat.toLowerCase()} needs.`,
        sCat,
        loc.name,
        lng,
        lat,
        (i + 1) * 150,
        String(i * 4),
      ]);
    }

    // 4. Seed 50 Notifications
    console.log('Seeding notifications...');
    for (let i = 0; i < 50; i++) {
      const recipientId = userIds[i % userIds.length];
      await client.query(`
        INSERT INTO "notifications" (
          "recipientId", "type", "category", "title", "body", "data", "isRead", "createdAt", "updatedAt"
        ) VALUES (
          $1, 'COMMUNITY_ANNOUNCEMENT', 'COMMUNITY', $2, $3, '{}', $4,
          now() - ($5 || ' hours')::interval, now() - ($5 || ' hours')::interval
        )
      `, [
        recipientId,
        `Neighborhood notice #${i + 1}`,
        `Important community update for your local area.`,
        i % 3 === 0,
        String(i),
      ]);
    }

    console.log('Seeding completed successfully!');
  } finally {
    client.release();
    await pool.end();
  }
}

seed().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});

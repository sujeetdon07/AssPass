/**
 * AASPAAS PHASE 12 — Performance & Scale Baseline & Verification Script
 *
 * Measures:
 * 1. Dataset size across all entities
 * 2. Redis operation latency (cache, rate-limit, presence)
 * 3. PostgreSQL query execution plans & timing via EXPLAIN ANALYZE
 * 4. REST API latencies (min, max, avg, p50, p95, p99, error rates)
 * 5. Target comparisons according to Phase 12 specification
 */

import pg from 'pg';
import Redis from 'ioredis';

const API_BASE = process.env.API_BASE || 'http://localhost:3000/api/v1';
const DB_URL = process.env.DATABASE_URL || 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db';
const REDIS_URL = process.env.REDIS_URL || 'redis://:aaspaas_redis_dev_password@localhost:6379';

const pool = new pg.Pool({ connectionString: DB_URL, max: 10 });
const redis = new Redis(REDIS_URL);

async function loginUser(phoneNumber) {
  // Clear any existing OTP cooldown/rate-limit so login succeeds reliably in benchmarks
  await redis.del(`otp:rate:${phoneNumber}`);
  await redis.del(`otp:cooldown:${phoneNumber}`);
  await redis.del(`otp:challenge:${phoneNumber}`);

  const reqRes = await fetch(`${API_BASE}/auth/otp/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phoneNumber }),
  });
  const reqJson = await reqRes.json();
  const devOtp = reqJson.data?.devOtp;
  if (!devOtp) {
    throw new Error(`Failed to request OTP for ${phoneNumber}: ${JSON.stringify(reqJson)}`);
  }

  const verifyRes = await fetch(`${API_BASE}/auth/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phoneNumber, otp: devOtp }),
  });
  const verifyJson = await verifyRes.json();
  if (!verifyJson.data?.tokens?.accessToken) {
    throw new Error(`Failed to verify OTP for ${phoneNumber}: ${JSON.stringify(verifyJson)}`);
  }

  return {
    userId: verifyJson.data.user.id,
    token: verifyJson.data.tokens.accessToken,
  };
}

// Helper for percentile calculation
function calculatePercentiles(latencies) {
  if (latencies.length === 0) return { min: 0, max: 0, avg: 0, p50: 0, p95: 0, p99: 0 };
  const sorted = [...latencies].sort((a, b) => a - b);
  const sum = sorted.reduce((acc, v) => acc + v, 0);
  const avg = Math.round((sum / sorted.length) * 100) / 100;
  const p50 = sorted[Math.floor(sorted.length * 0.50)];
  const p95 = sorted[Math.floor(sorted.length * 0.95)];
  const p99 = sorted[Math.floor(sorted.length * 0.99)];
  const min = sorted[0];
  const max = sorted[sorted.length - 1];
  return { min, max, avg, p50, p95, p99 };
}

// Format table row
function formatRow(cols, widths) {
  return cols.map((col, i) => String(col).padEnd(widths[i])).join(' | ');
}

async function main() {
  console.log('===============================================================');
  console.log('       AASPAAS PHASE 12 — PERFORMANCE BENCHMARK SUITE          ');
  console.log('===============================================================\n');

  // 1. DATASET AUDIT
  console.log('--- 1. DATASET SIZE AUDIT ---');
  const tables = [
    'users',
    'posts',
    'post_reactions',
    'comments',
    'communities',
    'community_members',
    'marketplace_listings',
    'businesses',
    'service_listings',
    'conversations',
    'conversation_participants',
    'messages',
    'notifications',
    'safety_reports',
    'moderation_audit_logs',
  ];

  const datasetCounts = {};
  for (const table of tables) {
    try {
      const res = await pool.query(`SELECT count(*)::int AS count FROM "${table}"`);
      datasetCounts[table] = res.rows[0].count;
      console.log(`  • ${table.padEnd(28)}: ${datasetCounts[table]} rows`);
    } catch (e) {
      datasetCounts[table] = 0;
      console.log(`  • ${table.padEnd(28)}: ERROR (${e.message})`);
    }
  }

  // 2. REDIS BENCHMARK
  console.log('\n--- 2. REDIS BENCHMARK (100 iterations each) ---');
  const redisOps = {
    'GET/SET Cache': async (i) => {
      const start = performance.now();
      await redis.set(`bench:cache:${i}`, JSON.stringify({ id: i, name: 'benchmark' }), 'EX', 60);
      await redis.get(`bench:cache:${i}`);
      return performance.now() - start;
    },
    'Rate-limit INCR+EXPIRE': async (i) => {
      const start = performance.now();
      await redis.incr(`bench:ratelimit:${i}`);
      await redis.expire(`bench:ratelimit:${i}`, 60);
      return performance.now() - start;
    },
    'Presence SET+GET': async (i) => {
      const start = performance.now();
      await redis.set(`presence:bench_${i}`, 'online', 'EX', 180);
      await redis.get(`presence:bench_${i}`);
      return performance.now() - start;
    },
  };

  const redisResults = {};
  for (const [opName, fn] of Object.entries(redisOps)) {
    const latencies = [];
    for (let i = 0; i < 100; i++) {
      const lat = await fn(i);
      latencies.push(lat);
    }
    const stats = calculatePercentiles(latencies);
    redisResults[opName] = stats;
    console.log(`  • ${opName.padEnd(25)} avg: ${stats.avg.toFixed(2)}ms | p50: ${stats.p50.toFixed(2)}ms | p95: ${stats.p95.toFixed(2)}ms | min: ${stats.min.toFixed(2)}ms | max: ${stats.max.toFixed(2)}ms`);
  }

  // Cleanup bench keys
  const benchKeys = await redis.keys('bench:*');
  if (benchKeys.length > 0) await redis.del(...benchKeys);

  // 3. DATABASE REPRESENTATIVE QUERY PLANS (EXPLAIN ANALYZE)
  console.log('\n--- 3. DATABASE QUERY PLANS (EXPLAIN ANALYZE) ---');
  const dbQueries = [
    {
      name: 'Feed Query (Locality + Category + CreatedAt DESC)',
      sql: `
        SELECT p."id", p."content", p."category", p."createdAt", u."displayName"
        FROM "posts" p
        LEFT JOIN "users" u ON u."id" = p."authorId"
        WHERE p."deletedAt" IS NULL AND (p."city" = 'Bengaluru' OR p."locality" = 'Indiranagar')
        ORDER BY p."createdAt" DESC, p."id" DESC
        LIMIT 20;
      `,
    },
    {
      name: 'Nearby PostGIS Spatial (ST_DWithin 5km radius)',
      sql: `
        SELECT p."id", p."content", p."locality",
               ST_Distance(p."location", ST_SetSRID(ST_MakePoint(77.6408, 12.9784), 4326)::geography) AS distance_meters
        FROM "posts" p
        WHERE p."deletedAt" IS NULL
          AND ST_DWithin(p."location", ST_SetSRID(ST_MakePoint(77.6408, 12.9784), 4326)::geography, 5000)
        ORDER BY distance_meters ASC
        LIMIT 20;
      `,
    },
    {
      name: 'Marketplace Listings (Locality + Category + Active)',
      sql: `
        SELECT m."id", m."title", m."price", m."createdAt", u."displayName"
        FROM "marketplace_listings" m
        LEFT JOIN "users" u ON u."id" = m."sellerId"
        WHERE m."deletedAt" IS NULL AND m."status" = 'active'
        ORDER BY m."createdAt" DESC
        LIMIT 20;
      `,
    },
    {
      name: 'Businesses (Locality + Active)',
      sql: `
        SELECT b."id", b."name", b."category", b."verificationStatus"
        FROM "businesses" b
        WHERE b."deletedAt" IS NULL AND b."status" = 'active'
        ORDER BY b."createdAt" DESC
        LIMIT 20;
      `,
    },
    {
      name: 'Service Listings (Locality + Active)',
      sql: `
        SELECT s."id", s."title", s."category", s."startingPrice"
        FROM "service_listings" s
        WHERE s."deletedAt" IS NULL AND s."status" = 'active'
        ORDER BY s."createdAt" DESC
        LIMIT 20;
      `,
    },
    {
      name: 'Conversations for User (User Participants + LastMessageAt DESC)',
      sql: `
        SELECT c."id", c."lastMessageAt", cp."lastReadAt"
        FROM "conversations" c
        JOIN "conversation_participants" cp ON cp."conversationId" = c."id"
        WHERE cp."userId" = (SELECT "id" FROM "users" LIMIT 1)
        ORDER BY c."lastMessageAt" DESC
        LIMIT 20;
      `,
    },
    {
      name: 'Messages in Conversation (ConversationId + CreatedAt DESC)',
      sql: `
        SELECT m."id", m."senderId", m."content", m."createdAt"
        FROM "messages" m
        WHERE m."conversationId" = (SELECT "id" FROM "conversations" LIMIT 1)
        ORDER BY m."createdAt" DESC
        LIMIT 30;
      `,
    },
    {
      name: 'Notifications for Recipient (RecipientId + CreatedAt DESC)',
      sql: `
        SELECT n."id", n."title", n."isRead", n."createdAt"
        FROM "notifications" n
        WHERE n."recipientId" = (SELECT "id" FROM "users" LIMIT 1)
        ORDER BY n."createdAt" DESC
        LIMIT 20;
      `,
    },
    {
      name: 'Moderation Safety Reports (Status + CreatedAt DESC)',
      sql: `
        SELECT r."id", r."targetType", r."targetId", r."reason", r."status", r."createdAt"
        FROM "safety_reports" r
        WHERE r."status" = 'pending'
        ORDER BY r."createdAt" DESC
        LIMIT 25;
      `,
    },
  ];

  const dbResults = [];
  for (const q of dbQueries) {
    try {
      const explainRes = await pool.query(`EXPLAIN (ANALYZE, FORMAT JSON) ${q.sql}`);
      const plan = explainRes.rows[0]['QUERY PLAN'][0];
      const execTime = plan['Execution Time'];
      const planningTime = plan['Planning Time'];
      const totalTime = Math.round((execTime + planningTime) * 100) / 100;
      const nodeType = plan['Plan']['Node Type'];
      dbResults.push({
        name: q.name,
        nodeType,
        planningTime,
        execTime,
        totalTime,
      });
      console.log(`  • ${q.name}`);
      console.log(`    Plan: ${nodeType} | Planning: ${planningTime.toFixed(2)}ms | Execution: ${execTime.toFixed(2)}ms | Total: ${totalTime.toFixed(2)}ms`);
    } catch (e) {
      console.log(`  • ${q.name}: Query skipped or empty reference (${e.message})`);
    }
  }

  // 4. REST API BENCHMARKS
  console.log('\n--- 4. REST API LATENCY BENCHMARKS ---');
  
  // Obtain JWT tokens for realistic authenticated calls
  const adminAuth = await loginUser('+919999000001');
  const adminToken = adminAuth.token;

  const userAuth = await loginUser('+919999000003');
  let userToken = userAuth.token;

  // Fetch sample IDs for detail requests
  let samplePostId = null;
  let sampleListingId = null;
  let sampleConvId = null;

  let messageToken = userToken;
  try {
    const pRes = await pool.query('SELECT "id" FROM "posts" WHERE "deletedAt" IS NULL LIMIT 1');
    if (pRes.rows.length > 0) samplePostId = pRes.rows[0].id;
    const lRes = await pool.query('SELECT "id" FROM "marketplace_listings" WHERE "deletedAt" IS NULL LIMIT 1');
    if (lRes.rows.length > 0) sampleListingId = lRes.rows[0].id;
    
    // Find conversation where user is participant, or pick any conversation and use its participant
    const cRes = await pool.query(
      'SELECT "conversationId" FROM "conversation_participants" WHERE "userId" = $1 LIMIT 1',
      [userAuth.userId]
    );
    if (cRes.rows.length > 0) {
      sampleConvId = cRes.rows[0].conversationId;
    } else {
      // Find any conversation and participant
      const anyCp = await pool.query('SELECT "conversationId", "userId" FROM "conversation_participants" LIMIT 1');
      if (anyCp.rows.length > 0) {
        sampleConvId = anyCp.rows[0].conversationId;
        // Re-authenticate as that user for messages test
        const participantUser = await pool.query('SELECT "phoneNumber" FROM "users" WHERE "id" = $1', [anyCp.rows[0].userId]);
        if (participantUser.rows.length > 0) {
          const partAuth = await loginUser(participantUser.rows[0].phoneNumber);
          messageToken = partAuth.token;
        }
      }
    }
  } catch (err) {
    console.warn('Warning during sample ID lookup:', err.message);
  }

  const apiEndpoints = [
    {
      name: 'Health Check (GET /health)',
      url: `${API_BASE}/health`,
      target: 100,
      headers: {},
    },
    {
      name: 'Auth Session (GET /auth/me)',
      url: `${API_BASE}/auth/me`,
      target: 300,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Feed List (GET /feed/posts?scope=local&limit=20)',
      url: `${API_BASE}/feed/posts?scope=local&limit=20`,
      target: 500,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    ...(samplePostId ? [{
      name: 'Feed Detail (GET /feed/posts/:id)',
      url: `${API_BASE}/feed/posts/${samplePostId}`,
      target: 400,
      headers: { Authorization: `Bearer ${userToken}` },
    }] : []),
    {
      name: 'Nearby Posts 1km (GET /nearby/posts?radius=1)',
      url: `${API_BASE}/nearby/posts?latitude=12.9784&longitude=77.6408&radius=1`,
      target: 700,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Nearby Posts 3km (GET /nearby/posts?radius=3)',
      url: `${API_BASE}/nearby/posts?latitude=12.9784&longitude=77.6408&radius=3`,
      target: 700,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Nearby Posts 5km (GET /nearby/posts?radius=5)',
      url: `${API_BASE}/nearby/posts?latitude=12.9784&longitude=77.6408&radius=5`,
      target: 700,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Nearby Posts 10km (GET /nearby/posts?radius=10)',
      url: `${API_BASE}/nearby/posts?latitude=12.9784&longitude=77.6408&radius=10`,
      target: 700,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Nearby Posts 20km (GET /nearby/posts?radius=20)',
      url: `${API_BASE}/nearby/posts?latitude=12.9784&longitude=77.6408&radius=20`,
      target: 700,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Communities List (GET /communities)',
      url: `${API_BASE}/communities`,
      target: 500,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Marketplace List (GET /marketplace/listings)',
      url: `${API_BASE}/marketplace/listings`,
      target: 500,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    ...(sampleListingId ? [{
      name: 'Marketplace Detail (GET /marketplace/listings/:id)',
      url: `${API_BASE}/marketplace/listings/${sampleListingId}`,
      target: 400,
      headers: { Authorization: `Bearer ${userToken}` },
    }] : []),
    {
      name: 'Businesses List (GET /businesses)',
      url: `${API_BASE}/businesses`,
      target: 500,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Services List (GET /services)',
      url: `${API_BASE}/services`,
      target: 500,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Notifications List (GET /notifications)',
      url: `${API_BASE}/notifications`,
      target: 500,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Notification Unread Count (GET /notifications/unread-count)',
      url: `${API_BASE}/notifications/unread-count`,
      target: 300,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Conversations List (GET /messaging/conversations)',
      url: `${API_BASE}/messaging/conversations`,
      target: 500,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    ...(sampleConvId ? [{
      name: 'Messages List (GET /messaging/conversations/:id/messages)',
      url: `${API_BASE}/messaging/conversations/${sampleConvId}/messages`,
      target: 500,
      headers: { Authorization: `Bearer ${messageToken}` },
    }] : []),
    {
      name: 'Safety Report History (GET /safety/reports/me)',
      url: `${API_BASE}/safety/reports/me`,
      target: 500,
      headers: { Authorization: `Bearer ${userToken}` },
    },
    {
      name: 'Admin Report List (GET /admin/reports)',
      url: `${API_BASE}/admin/reports`,
      target: 500,
      headers: { Authorization: `Bearer ${adminToken}` },
    },
    {
      name: 'Admin User List (GET /admin/users)',
      url: `${API_BASE}/admin/users`,
      target: 500,
      headers: { Authorization: `Bearer ${adminToken}` },
    },
    {
      name: 'Admin Dashboard Summary (GET /admin/dashboard/summary)',
      url: `${API_BASE}/admin/dashboard/summary`,
      target: 500,
      headers: { Authorization: `Bearer ${adminToken}` },
    },
  ];

  const iterations = 10; // 10 iterations per endpoint for stable statistical sampling
  console.log(`Running ${iterations} iterations per API endpoint...\n`);

  const headers = ['Endpoint', 'Reqs', 'Min(ms)', 'p50(ms)', 'p95(ms)', 'p99(ms)', 'Max(ms)', 'Target', 'Status'];
  const widths = [48, 4, 7, 7, 7, 7, 7, 7, 24];
  console.log(formatRow(headers, widths));
  console.log('-'.repeat(widths.reduce((a, b) => a + b + 3, 0)));

  const apiResults = [];

  for (const ep of apiEndpoints) {
    // Reset rate limiter keys so each endpoint group can measure raw latency
    const rateKeys = await redis.keys('rate:*');
    if (rateKeys.length > 0) {
      await redis.del(...rateKeys);
    }

    const latencies = [];
    let failures = 0;

    for (let i = 0; i < iterations; i++) {
      const start = performance.now();
      try {
        const res = await fetch(ep.url, { headers: ep.headers });
        const lat = performance.now() - start;
        if (res.ok) {
          latencies.push(lat);
        } else {
          failures++;
        }
      } catch {
        failures++;
      }
    }

    const stats = calculatePercentiles(latencies);
    let statusText = 'TARGET MET';
    if (failures > 0) {
      statusText = `FAILED (${failures} errors)`;
    } else if (stats.p95 <= ep.target) {
      statusText = 'TARGET MET';
    } else if (stats.p95 <= ep.target * 1.5) {
      statusText = 'ACCEPTABLE FOR CURRENT ENV';
    } else {
      statusText = 'NEEDS OPTIMIZATION';
    }

    apiResults.push({
      name: ep.name,
      requests: latencies.length,
      failures,
      stats,
      target: ep.target,
      status: statusText,
    });

    console.log(
      formatRow(
        [
          ep.name,
          latencies.length,
          stats.min.toFixed(1),
          stats.p50.toFixed(1),
          stats.p95.toFixed(1),
          stats.p99.toFixed(1),
          stats.max.toFixed(1),
          `<${ep.target}ms`,
          statusText,
        ],
        widths,
      ),
    );
  }

  console.log('\n===============================================================');
  console.log('                 BENCHMARK RUN COMPLETED                       ');
  console.log('===============================================================\n');

  await pool.end();
  await redis.quit();
}

main().catch(async (err) => {
  console.error('Benchmark execution error:', err);
  await pool.end();
  await redis.quit();
  process.exit(1);
});

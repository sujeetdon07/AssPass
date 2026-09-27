/**
 * AASPAAS PHASE 12 — Controlled Concurrency & Load Test
 *
 * Evaluates representative API workloads under concurrent client loads:
 * Levels: 5, 10, 25, 50 concurrent clients.
 *
 * Metrics recorded:
 * - Throughput (req/s)
 * - Latencies: min, avg, p50, p95, p99, max
 * - Error rate & HTTP 429 rate
 * - PostgreSQL pool & Redis responsiveness
 *
 * Note: Clearly labeled as a local development benchmark.
 */

import pg from 'pg';
import Redis from 'ioredis';

const API_BASE = process.env.API_BASE || 'http://localhost:3000/api/v1';
const DB_URL = process.env.DATABASE_URL || 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db';
const REDIS_URL = process.env.REDIS_URL || 'redis://:aaspaas_redis_dev_password@localhost:6379';

const pool = new pg.Pool({ connectionString: DB_URL, max: 10 });
const redis = new Redis(REDIS_URL);

async function loginUser(phoneNumber) {
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

  const verifyRes = await fetch(`${API_BASE}/auth/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phoneNumber, otp: devOtp }),
  });
  const verifyJson = await verifyRes.json();
  return verifyJson.data.tokens.accessToken;
}

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

async function runWorker(workerId, token, requestCount, endpoints) {
  const latencies = [];
  let errors = 0;
  let rateLimits = 0;

  for (let i = 0; i < requestCount; i++) {
    const ep = endpoints[i % endpoints.length];
    const start = performance.now();
    try {
      const res = await fetch(ep.url, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const lat = performance.now() - start;
      if (res.status === 200 || res.status === 201) {
        latencies.push(lat);
      } else if (res.status === 429) {
        rateLimits++;
      } else {
        errors++;
      }
    } catch {
      errors++;
    }
  }

  return { latencies, errors, rateLimits };
}

async function runConcurrencyLevel(concurrency, totalRequests, token, endpoints) {
  const reqsPerWorker = Math.ceil(totalRequests / concurrency);
  const actualTotal = reqsPerWorker * concurrency;

  // Clear rate limits before starting level
  const rateKeys = await redis.keys('rate:*');
  if (rateKeys.length > 0) await redis.del(...rateKeys);

  const startTime = performance.now();
  const workerPromises = [];

  for (let c = 0; c < concurrency; c++) {
    workerPromises.push(runWorker(c, token, reqsPerWorker, endpoints));
  }

  const results = await Promise.all(workerPromises);
  const durationSec = (performance.now() - startTime) / 1000;

  const allLatencies = [];
  let totalErrors = 0;
  let totalRateLimits = 0;

  for (const r of results) {
    allLatencies.push(...r.latencies);
    totalErrors += r.errors;
    totalRateLimits += r.rateLimits;
  }

  const throughput = Math.round((allLatencies.length / durationSec) * 10) / 10;
  const stats = calculatePercentiles(allLatencies);
  const errorRate = Math.round((totalErrors / actualTotal) * 1000) / 10;
  const rateLimitRate = Math.round((totalRateLimits / actualTotal) * 1000) / 10;

  return {
    concurrency,
    totalRequests: actualTotal,
    successful: allLatencies.length,
    durationSec: Math.round(durationSec * 100) / 100,
    throughput,
    errorRate,
    rateLimitRate,
    stats,
  };
}

async function main() {
  console.log('========================================================================');
  console.log('   AASPAAS PHASE 12 — CONTROLLED CONCURRENCY / LOAD BENCHMARK           ');
  console.log('   (Local Development Environment Benchmark — Non-destructive)        ');
  console.log('========================================================================\n');

  console.log('Authenticating benchmark user...');
  const token = await loginUser('+919999000003');
  console.log('✓ Benchmark user authenticated.\n');

  // Verify infrastructure before load test
  const dbHealthBefore = await pool.query('SELECT 1 AS alive');
  const redisPingBefore = await redis.ping();
  console.log(`Pre-test Infrastructure: DB=${dbHealthBefore.rows[0].alive === 1 ? 'OK' : 'ERR'}, Redis=${redisPingBefore}`);

  const endpoints = [
    { name: 'Feed', url: `${API_BASE}/feed/posts?scope=local&limit=20` },
    { name: 'Nearby', url: `${API_BASE}/nearby/posts?latitude=12.9784&longitude=77.6408&radius=5` },
    { name: 'Marketplace', url: `${API_BASE}/marketplace/listings` },
    { name: 'Businesses', url: `${API_BASE}/businesses` },
    { name: 'Notifications', url: `${API_BASE}/notifications` },
  ];

  const levels = [
    { concurrency: 5, requests: 50 },
    { concurrency: 10, requests: 100 },
    { concurrency: 25, requests: 150 },
    { concurrency: 50, requests: 200 },
  ];

  console.log('\nStarting concurrent client evaluations...\n');

  const headers = ['Concurrency', 'Requests', 'Time(s)', 'Throughput(req/s)', 'p50(ms)', 'p95(ms)', 'p99(ms)', 'Max(ms)', 'Errors%', '429%'];
  const widths = [12, 9, 8, 19, 8, 8, 8, 8, 8, 6];
  console.log(headers.map((h, i) => h.padEnd(widths[i])).join(' | '));
  console.log('-'.repeat(widths.reduce((a, b) => a + b + 3, 0)));

  const summary = [];

  for (const lvl of levels) {
    const res = await runConcurrencyLevel(lvl.concurrency, lvl.requests, token, endpoints);
    summary.push(res);
    console.log(
      [
        `${res.concurrency} clients`.padEnd(widths[0]),
        String(res.totalRequests).padEnd(widths[1]),
        `${res.durationSec}s`.padEnd(widths[2]),
        `${res.throughput}`.padEnd(widths[3]),
        `${res.stats.p50.toFixed(1)}`.padEnd(widths[4]),
        `${res.stats.p95.toFixed(1)}`.padEnd(widths[5]),
        `${res.stats.p99.toFixed(1)}`.padEnd(widths[6]),
        `${res.stats.max.toFixed(1)}`.padEnd(widths[7]),
        `${res.errorRate}%`.padEnd(widths[8]),
        `${res.rateLimitRate}%`.padEnd(widths[9]),
      ].join(' | '),
    );
  }

  // Verify infrastructure responsiveness post-load test
  const dbHealthAfter = await pool.query('SELECT 1 AS alive');
  const redisPingAfter = await redis.ping();
  console.log(`\nPost-test Infrastructure: DB=${dbHealthAfter.rows[0].alive === 1 ? 'OK' : 'ERR'}, Redis=${redisPingAfter}`);

  console.log('\n========================================================================');
  console.log('              CONCURRENCY BENCHMARK COMPLETE                            ');
  console.log('========================================================================\n');

  await pool.end();
  await redis.quit();
}

main().catch(async (err) => {
  console.error('Concurrency test failed:', err);
  await pool.end();
  await redis.quit();
  process.exit(1);
});

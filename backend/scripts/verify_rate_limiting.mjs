// Aaspaas Phase 6 Marketplace Rate Limiting Verification
import { Client } from 'pg';

const BASE_URL = 'http://localhost:3000/api/v1';

async function api(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  let body = null;
  const text = await res.text();
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { status: res.status, body };
}

async function main() {
  console.log('--- STARTING RATE LIMITING RUNTIME VERIFICATION ---');

  // Authenticate User A (+919876543210)
  const otpResA = await api('/auth/otp/request', {
    method: 'POST',
    body: JSON.stringify({ phoneNumber: '+919876543210' }),
  });
  const devOtpA = otpResA.body?.data?.devOtp || otpResA.body?.devOtp;
  const verifyResA = await api('/auth/otp/verify', {
    method: 'POST',
    body: JSON.stringify({ phoneNumber: '+919876543210', otp: devOtpA }),
  });
  const tokenA = verifyResA.body?.data?.tokens?.accessToken || verifyResA.body?.tokens?.accessToken;
  const userA = verifyResA.body?.data?.user || verifyResA.body?.user;

  // Authenticate User B (+919876543211)
  const otpResB = await api('/auth/otp/request', {
    method: 'POST',
    body: JSON.stringify({ phoneNumber: '+919876543211' }),
  });
  const devOtpB = otpResB.body?.data?.devOtp || otpResB.body?.devOtp;
  const verifyResB = await api('/auth/otp/verify', {
    method: 'POST',
    body: JSON.stringify({ phoneNumber: '+919876543211', otp: devOtpB }),
  });
  const tokenB = verifyResB.body?.data?.tokens?.accessToken || verifyResB.body?.tokens?.accessToken;
  const userB = verifyResB.body?.data?.user || verifyResB.body?.user;

  console.log(`User A: ${userA.id}, User B: ${userB.id}`);

  // Test 1: Search Rate Limiting (60 requests per minute per user)
  console.log('Testing Search Rate Limit (60/min)...');
  let searchSuccessCount = 0;
  let search429Seen = false;
  let search429Message = '';

  for (let i = 0; i < 65; i++) {
    const res = await api('/marketplace/listings?limit=1', {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    if (res.status === 200) {
      searchSuccessCount++;
    } else if (res.status === 429) {
      search429Seen = true;
      search429Message = res.body?.error?.message || JSON.stringify(res.body);
      break;
    }
  }

  console.log(`User A made ${searchSuccessCount} successful searches before 429.`);
  console.log(`429 received: ${search429Seen}, message: "${search429Message}"`);

  // Verify User B is NOT blocked by User A's rate limit
  const userBSearch = await api('/marketplace/listings?limit=1', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  console.log(`User B search status while User A is rate limited: ${userBSearch.status}`);

  const searchRateLimitPassed =
    searchSuccessCount === 60 &&
    search429Seen &&
    userBSearch.status === 200;

  console.log(
    searchRateLimitPassed
      ? '✅ PASS [Search Rate Limiting] 60 requests allowed, 61st returned 429, User B unaffected.'
      : '❌ FAIL [Search Rate Limiting]'
  );

  // Test 2: Reports Rate Limiting (10 requests per hour per user)
  // Create 12 dummy listings by User A for User B to report
  console.log('Creating listings for report rate limit test...');
  const listingIds = [];
  for (let i = 0; i < 12; i++) {
    const createRes = await api('/marketplace/listings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokenA}` },
      body: JSON.stringify({
        title: `Rate Limit Test Listing ${i + 1}`,
        description: 'Listing to test reporting rate limits',
        category: 'other',
        condition: 'used',
        price: 100 + i,
        locality: 'Koramangala',
      }),
    });
    if (createRes.status === 201) {
      listingIds.push((createRes.body?.data || createRes.body).id);
    }
  }

  console.log(`Created ${listingIds.length} listings.`);

  let reportSuccessCount = 0;
  let report429Seen = false;
  let report429Message = '';

  for (let i = 0; i < listingIds.length; i++) {
    const res = await api(`/marketplace/listings/${listingIds[i]}/report`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokenB}` },
      body: JSON.stringify({
        reason: 'spam',
        details: `Report number ${i + 1}`,
      }),
    });
    if (res.status === 200) {
      reportSuccessCount++;
    } else if (res.status === 429) {
      report429Seen = true;
      report429Message = res.body?.error?.message || JSON.stringify(res.body);
      break;
    }
  }

  console.log(`User B made ${reportSuccessCount} successful reports before 429.`);
  console.log(`429 received: ${report429Seen}, message: "${report429Message}"`);

  const reportRateLimitPassed =
    reportSuccessCount === 10 &&
    report429Seen;

  console.log(
    reportRateLimitPassed
      ? '✅ PASS [Report Rate Limiting] 10 reports allowed, 11th returned 429.'
      : '❌ FAIL [Report Rate Limiting]'
  );
}

main().catch(err => {
  console.error('Execution error:', err);
  process.exit(1);
});

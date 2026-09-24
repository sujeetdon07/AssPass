const BASE_URL = 'http://localhost:3000/api/v1';

async function request(endpoint, options = {}) {
  const url = `${BASE_URL}${endpoint}`;
  const response = await fetch(url, {
    method: options.method || 'GET',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
      ...(options.headers || {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  let data;
  try {
    data = await response.json();
  } catch {
    data = null;
  }

  return { status: response.status, data };
}

async function authenticateUser(phone, name) {
  const otpRes = await request('/auth/otp/request', {
    method: 'POST',
    body: { phoneNumber: phone },
  });
  const otp = otpRes.data?.data?.devOtp || '123456';

  const verifyRes = await request('/auth/otp/verify', {
    method: 'POST',
    body: { phoneNumber: phone, otp },
  });
  const token = verifyRes.data.data.tokens.accessToken;
  const user = verifyRes.data.data.user;

  if (!user.onboardingCompleted) {
    await request('/users/me/onboarding', {
      method: 'PATCH',
      token,
      body: {
        displayName: name,
        locality: 'Koramangala',
        city: 'Bengaluru',
        state: 'Karnataka',
        countryCode: 'IN',
      },
    });
  }

  return { token, user };
}

function assert(condition, message) {
  if (!condition) {
    console.error(`❌ FAILED: ${message}`);
    process.exit(1);
  }
  console.log(`  ✅ ${message}`);
}

async function verifyRateLimiting() {
  console.log('====================================================');
  console.log('⏱️ AASPAAS PHASE 4 — RATE LIMITING VERIFICATION');
  console.log('====================================================\n');

  console.log('1. Authenticating User A and User B...');
  const suffix = Date.now().toString().slice(-6);
  const userA = await authenticateUser(`+9198${suffix}01`, 'Rate Limit User A');
  const userB = await authenticateUser(`+9198${suffix}02`, 'Rate Limit User B');
  assert(userA.token && userB.token, 'Both users authenticated');

  console.log('\n2. Testing requests 1 to 60 for User A (within limit 60/min)...');
  let userASuccessCount = 0;
  for (let i = 1; i <= 60; i++) {
    const res = await request('/nearby/posts?latitude=12.9352&longitude=77.6245&radius=5', {
      method: 'GET',
      token: userA.token,
    });
    if (res.status === 200) {
      userASuccessCount++;
    } else {
      console.error(`Request ${i} failed unexpectedly with status ${res.status}:`, res.data);
      break;
    }
  }
  assert(userASuccessCount === 60, `User A made 60 successful requests: ${userASuccessCount}/60`);

  console.log('\n3. Testing request 61 for User A (exceeds limit 60/min)...');
  const res61 = await request('/nearby/posts?latitude=12.9352&longitude=77.6245&radius=5', {
    method: 'GET',
    token: userA.token,
  });
  assert(res61.status === 429, `Request 61 returned HTTP 429 Too Many Requests (got ${res61.status})`);
  assert(
    res61.data?.error?.code === 'RATE_LIMITED' || res61.data?.error?.message?.includes('Too many nearby searches'),
    `Response message confirms rate limiting: ${JSON.stringify(res61.data)}`,
  );

  console.log('\n4. Verifying User B is NOT blocked by User A’s rate limit (user scoping)...');
  const resUserB = await request('/nearby/posts?latitude=12.9352&longitude=77.6245&radius=5', {
    method: 'GET',
    token: userB.token,
  });
  assert(resUserB.status === 200, `User B request succeeded with HTTP 200 (got ${resUserB.status})`);

  console.log('\n====================================================');
  console.log('🎉 RATE LIMITING VERIFICATION SUCCESSFUL');
  console.log('====================================================');
}

verifyRateLimiting().catch((err) => {
  console.error('Rate limiting verification error:', err);
  process.exit(1);
});

import http from 'node:http';

const BASE_URL = 'http://localhost:3000/api/v1';

async function request(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${BASE_URL}${path}`);
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(url, { method, headers }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          resolve({ status: res.statusCode, data: json });
        } catch {
          resolve({ status: res.statusCode, text: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function maskToken(t) {
  if (!t || t.length < 20) return t;
  return `${t.substring(0, 10)}...${t.substring(t.length - 8)} (length: ${t.length})`;
}

async function runVerification() {
  console.log('================================================================');
  console.log('       AASPAAS PHASE 2 RUNTIME & SECURITY VERIFICATION          ');
  console.log('================================================================\n');

  const testPhone = '+919999900005';

  // ───────────────────────────────────────────────────────────────────────────
  // 1. HEALTH & METRICS
  // ───────────────────────────────────────────────────────────────────────────
  console.log('--- 1. BACKEND & INFRASTRUCTURE VERIFICATION ---');
  const health = await request('GET', '/health');
  console.log(`[Health] Status: ${health.status}, Response:`, JSON.stringify(health.data));
  if (health.status !== 200 || health.data.database !== 'connected' || health.data.redis !== 'connected') {
    throw new Error('Health check failed!');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. AUTHENTICATION FLOW: REQUEST OTP
  // ───────────────────────────────────────────────────────────────────────────
  console.log('\n--- 2.A REQUEST OTP ---');
  const otpReq = await request('POST', '/auth/otp/request', { phoneNumber: testPhone });
  console.log(`[Request OTP] Status: ${otpReq.status}`);
  console.log(`[Request OTP] Masked Phone: ${otpReq.data.data?.maskedPhoneNumber}`);
  console.log(`[Request OTP] Cooldown: ${otpReq.data.data?.cooldownSeconds}s, Expiry: ${otpReq.data.data?.expiresInSeconds}s`);
  console.log(`[Request OTP] Dev OTP: ${otpReq.data.data?.devOtp}`);
  const devOtp = otpReq.data.data?.devOtp;

  // Test cooldown immediate resend
  const cooldownReq = await request('POST', '/auth/otp/request', { phoneNumber: testPhone });
  console.log(`[Cooldown Rejection] Status: ${cooldownReq.status} (expected 429)`);
  console.log(`[Cooldown Message]: ${cooldownReq.data?.error?.message}`);

  // ───────────────────────────────────────────────────────────────────────────
  // 2.B VERIFY OTP
  // ───────────────────────────────────────────────────────────────────────────
  console.log('\n--- 2.B VERIFY OTP & SESSION CREATION ---');
  const verifyRes = await request('POST', '/auth/otp/verify', {
    phoneNumber: testPhone,
    otp: devOtp,
    deviceMetadata: { platform: 'Android 15', model: 'Pixel 10 Pro' },
  });
  console.log(`[Verify OTP] Status: ${verifyRes.status}`);
  console.log(`[Verify OTP] User ID: ${verifyRes.data.data?.user?.id}`);
  console.log(`[Verify OTP] Phone: ${verifyRes.data.data?.user?.phoneNumber}`);
  console.log(`[Verify OTP] Onboarding Completed: ${verifyRes.data.data?.user?.onboardingCompleted}`);
  console.log(`[Verify OTP] Access Token: ${maskToken(verifyRes.data.data?.tokens?.accessToken)}`);
  console.log(`[Verify OTP] Refresh Token: ${maskToken(verifyRes.data.data?.tokens?.refreshToken)}`);

  const accessToken = verifyRes.data.data?.tokens?.accessToken;
  const refreshToken = verifyRes.data.data?.tokens?.refreshToken;

  // ───────────────────────────────────────────────────────────────────────────
  // 2.C AUTHENTICATED /me
  // ───────────────────────────────────────────────────────────────────────────
  console.log('\n--- 2.C GET /auth/me ---');
  const meRes = await request('GET', '/auth/me', null, accessToken);
  console.log(`[GET /auth/me] Status: ${meRes.status}`);
  console.log(`[GET /auth/me] Response User ID: ${meRes.data.data?.id}`);
  console.log(`[GET /auth/me] Phone Masked: ${meRes.data.data?.phoneNumber}`);
  console.log(`[GET /auth/me] Locality (no exact coords):`, JSON.stringify(meRes.data.data?.locality));

  // ───────────────────────────────────────────────────────────────────────────
  // 2.D ONBOARDING
  // ───────────────────────────────────────────────────────────────────────────
  console.log('\n--- 2.D ONBOARDING (PATCH /users/me/onboarding) ---');
  // Validation failure test
  const badOnboarding = await request('PATCH', '/users/me/onboarding', { displayName: '' }, accessToken);
  console.log(`[Onboarding Invalid Validation] Status: ${badOnboarding.status} (expected 400)`);
  console.log(`[Onboarding Invalid Error]: ${badOnboarding.data?.error?.message}`);

  // Valid onboarding
  const goodOnboarding = await request('PATCH', '/users/me/onboarding', {
    displayName: 'Aakash Verma',
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Koramangala',
    neighborhood: '4th Block',
  }, accessToken);
  console.log(`[Onboarding Valid] Status: ${goodOnboarding.status}`);
  console.log(`[Onboarding Valid] Name: ${goodOnboarding.data.data?.displayName}`);
  console.log(`[Onboarding Valid] Onboarding Completed: ${goodOnboarding.data.data?.onboardingCompleted}`);
  console.log(`[Onboarding Valid] Locality:`, JSON.stringify(goodOnboarding.data.data?.locality));

  // ───────────────────────────────────────────────────────────────────────────
  // 2.E TOKEN REFRESH & ROTATION
  // ───────────────────────────────────────────────────────────────────────────
  console.log('\n--- 2.E REFRESH TOKEN ROTATION ---');
  const refreshRes1 = await request('POST', '/auth/refresh', { refreshToken });
  console.log(`[Refresh 1] Status: ${refreshRes1.status}`);
  console.log(`[Refresh 1] New Access Token: ${maskToken(refreshRes1.data.data?.accessToken)}`);
  console.log(`[Refresh 1] New Refresh Token: ${maskToken(refreshRes1.data.data?.refreshToken)}`);

  const rotatedAccessToken = refreshRes1.data.data?.accessToken;
  const rotatedRefreshToken = refreshRes1.data.data?.refreshToken;

  // Replay old refresh token (MUST FAIL & REVOKE)
  console.log('\n[Replay Attack Test] Replaying old refresh token:');
  const replayRes = await request('POST', '/auth/refresh', { refreshToken });
  console.log(`[Replay Attack] Status: ${replayRes.status} (expected 401)`);
  console.log(`[Replay Attack Error]: ${replayRes.data?.error?.message}`);

  // Verify that replay caused session revocation: rotatedRefreshToken should also now fail!
  const revokedRefreshCheck = await request('POST', '/auth/refresh', { refreshToken: rotatedRefreshToken });
  console.log(`[Revoked Session Refresh] Status: ${revokedRefreshCheck.status} (expected 401 after replay attack)`);
  console.log(`[Revoked Session Refresh Error]: ${revokedRefreshCheck.data?.error?.message}`);

  // ───────────────────────────────────────────────────────────────────────────
  // 2.F LOGOUT
  // ───────────────────────────────────────────────────────────────────────────
  console.log('\n--- 2.F LOGOUT & SESSION TERMINATION ---');
  // Log in again to get fresh session to test logout
  const otp2 = await request('POST', '/auth/otp/request', { phoneNumber: '+919999900006' });
  const verify2 = await request('POST', '/auth/otp/verify', {
    phoneNumber: '+919999900006',
    otp: otp2.data.data?.devOtp,
  });
  const logoutAccessToken = verify2.data.data?.tokens?.accessToken;
  const logoutRefreshToken = verify2.data.data?.tokens?.refreshToken;

  const logoutRes = await request('POST', '/auth/logout', null, logoutAccessToken);
  console.log(`[Logout] Status: ${logoutRes.status}`);
  console.log(`[Logout Response]:`, JSON.stringify(logoutRes.data));

  // Verify access token after logout
  const meAfterLogout = await request('GET', '/auth/me', null, logoutAccessToken);
  console.log(`[GET /auth/me after logout] Status: ${meAfterLogout.status} (expected 401)`);

  // Verify refresh token after logout
  const refreshAfterLogout = await request('POST', '/auth/refresh', { refreshToken: logoutRefreshToken });
  console.log(`[POST /auth/refresh after logout] Status: ${refreshAfterLogout.status} (expected 401)`);

  // ───────────────────────────────────────────────────────────────────────────
  // 3. SECURITY BOUNDARIES
  // ───────────────────────────────────────────────────────────────────────────
  console.log('\n--- 3. SECURITY BOUNDARIES VERIFICATION ---');

  // A. OTP Invalid attempt & Max attempts lockout
  console.log('\n[Security] Testing OTP attempt locking (max 5 failed attempts):');
  const lockPhone = `+9199999${Math.floor(10000 + Math.random() * 90000)}`;
  const otpLockTest = await request('POST', '/auth/otp/request', { phoneNumber: lockPhone });
  const correctLockOtp = otpLockTest.data.data?.devOtp;
  for (let i = 1; i <= 5; i++) {
    const badOtp = await request('POST', '/auth/otp/verify', {
      phoneNumber: lockPhone,
      otp: '000000',
    });
    console.log(`  Attempt ${i}: status=${badOtp.status}, message="${badOtp.data?.error?.message}"`);
  }
  // 6th attempt after lockout
  const postLockAttempt = await request('POST', '/auth/otp/verify', {
    phoneNumber: lockPhone,
    otp: correctLockOtp, // even correct OTP should now fail!
  });
  console.log(`  Post-Lockout (with correct OTP): status=${postLockAttempt.status}, message="${postLockAttempt.data?.error?.message}"`);

  // B. Authentication Token Boundaries
  console.log('\n[Security] Testing JWT Authentication Boundaries:');
  const noToken = await request('GET', '/auth/me');
  console.log(`  Missing Token: status=${noToken.status} (expected 401)`);

  const malformedToken = await request('GET', '/auth/me', null, 'malformed.jwt.token');
  console.log(`  Malformed Token: status=${malformedToken.status} (expected 401)`);

  const forgedToken = await request('GET', '/auth/me', null, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMTExMTExMS0yMjIyLTMzMzMtNDQ0NC01NTU1NTU1NTU1NTUiLCJzaWQiOiIyMjIyMjIyMi0zMzMzLTQ0NDQtNTU1NS02NjY2NjY2NjY2NjYiLCJpYXQiOjE3OTAwNzU0NjMsImV4cCI6MTc5MDA3NjM2M30.INVALID_SIGNATURE');
  console.log(`  Forged Signature Token: status=${forgedToken.status} (expected 401)`);

  // C. Localities Search
  console.log('\n[Localities] Testing locality search & privacy:');
  const locSearch = await request('GET', '/localities/search?q=Indiranagar');
  console.log(`  Search "Indiranagar": status=${locSearch.status}, results=${locSearch.data.data?.length}`);
  console.log(`  Top result:`, JSON.stringify(locSearch.data.data?.[0]));

  console.log('\n================================================================');
  console.log('         ALL RUNTIME & SECURITY VERIFICATIONS COMPLETED         ');
  console.log('================================================================');
}

runVerification().catch((err) => {
  console.error('FATAL Runtime Verification Error:', err);
  process.exit(1);
});

// Aaspaas Phase 2-5 Live Regression Verification
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
  console.log('--- STARTING PHASES 2-5 REGRESSION RUNTIME VERIFICATION ---');

  // ── PHASE 2: Auth & Session ───────────────────────────────────────────────
  const otpRes = await api('/auth/otp/request', {
    method: 'POST',
    body: JSON.stringify({ phoneNumber: '+919876543220' }),
  });
  const devOtp = otpRes.body?.data?.devOtp || otpRes.body?.devOtp;
  const verifyRes = await api('/auth/otp/verify', {
    method: 'POST',
    body: JSON.stringify({ phoneNumber: '+919876543220', otp: devOtp }),
  });
  const token = verifyRes.body?.data?.tokens?.accessToken || verifyRes.body?.tokens?.accessToken;
  const refreshToken = verifyRes.body?.data?.tokens?.refreshToken || verifyRes.body?.tokens?.refreshToken;

  // Onboard User
  const onboardRes = await api('/users/me/onboarding', {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      displayName: 'Rohan Verma',
      city: 'Bengaluru',
      locality: 'Koramangala',
      neighborhood: '5th Block',
    }),
  });

  // Me endpoint
  const meRes = await api('/auth/me', {
    headers: { Authorization: `Bearer ${token}` },
  });

  // Refresh token
  const refreshRes = await api('/auth/refresh', {
    method: 'POST',
    body: JSON.stringify({ refreshToken }),
  });

  const p2Pass = meRes.status === 200 && refreshRes.status === 200 && onboardRes.status === 200;
  console.log(p2Pass ? '✅ PASS [Phase 2 - Authentication & Session]' : '❌ FAIL [Phase 2 - Authentication & Session]');

  // ── PHASE 3: Community Feed, Posts, Like & Comment ─────────────────────────
  const createPostRes = await api('/feed/posts', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      content: 'Community notice: Annual tree plantation drive this weekend in Koramangala!',
      category: 'general',
    }),
  });
  const post = createPostRes.body?.data || createPostRes.body;
  const postId = post?.id;

  const feedRes = await api('/feed/posts', {
    headers: { Authorization: `Bearer ${token}` },
  });

  const likeRes = await api(`/feed/posts/${postId}/like`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });

  const commentRes = await api(`/feed/posts/${postId}/comments`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify({ content: 'I will definitely join!' }),
  });

  const p3Pass = createPostRes.status === 201 && feedRes.status === 200 && likeRes.status === 200 && commentRes.status === 201;
  console.log(p3Pass ? '✅ PASS [Phase 3 - Community Feed, Posts, Like & Comment]' : `❌ FAIL [Phase 3] create: ${createPostRes.status}, feed: ${feedRes.status}, like: ${likeRes.status}, comment: ${commentRes.status}`);

  // ── PHASE 4: Nearby Spatial Discovery ──────────────────────────────────────
  const nearbyRes = await api('/nearby/posts?latitude=12.9352&longitude=77.6245&radius=5', {
    headers: { Authorization: `Bearer ${token}` },
  });
  const nearbyData = nearbyRes.body?.data || nearbyRes.body;
  const nearbyItems = nearbyData.items || [];

  const p4Pass = nearbyRes.status === 200 && nearbyItems.length > 0;
  console.log(p4Pass ? `✅ PASS [Phase 4 - Nearby Discovery] Returned ${nearbyItems.length} nearby post(s)` : `❌ FAIL [Phase 4 - Nearby Discovery] status: ${nearbyRes.status}`);

  // ── PHASE 5: Communities ──────────────────────────────────────────────────
  const createCommRes = await api('/communities', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      name: 'Koramangala Green Club',
      description: 'Neighborhood eco-initiative club in Koramangala for tree plantation.',
      category: 'neighborhood',
      city: 'Bengaluru',
      locality: 'Koramangala',
    }),
  });
  const comm = createCommRes.body?.data || createCommRes.body;
  const commId = comm?.id;

  const getCommRes = await api(`/communities/${commId}`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  const listCommRes = await api('/communities', {
    headers: { Authorization: `Bearer ${token}` },
  });

  const p5Pass = createCommRes.status === 201 && getCommRes.status === 200 && listCommRes.status === 200;
  console.log(p5Pass ? '✅ PASS [Phase 5 - Communities Discovery & Details]' : `❌ FAIL [Phase 5] create: ${createCommRes.status}, get: ${getCommRes.status}, list: ${listCommRes.status}`);

  if (p2Pass && p3Pass && p4Pass && p5Pass) {
    console.log('\n🎉 ALL REGRESSION TESTS PASSED (Phases 2, 3, 4, 5)!');
  } else {
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Regression error:', err);
  process.exit(1);
});

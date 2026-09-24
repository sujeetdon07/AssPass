import http from 'http';

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

async function authenticateUser(phone, name, locality, city) {
  // 1. Request OTP
  const otpRes = await request('/auth/otp/request', {
    method: 'POST',
    body: { phoneNumber: phone },
  });
  if (otpRes.status !== 200 && otpRes.status !== 201) {
    throw new Error(`OTP request failed for ${phone}: ${JSON.stringify(otpRes.data)}`);
  }
  const otp = otpRes.data?.data?.devOtp || '123456';

  // 2. Verify OTP
  const verifyRes = await request('/auth/otp/verify', {
    method: 'POST',
    body: { phoneNumber: phone, otp },
  });
  if (verifyRes.status !== 200 && verifyRes.status !== 201) {
    throw new Error(`OTP verify failed for ${phone}: ${JSON.stringify(verifyRes.data)}`);
  }
  const token = verifyRes.data.data.tokens.accessToken;
  const user = verifyRes.data.data.user;

  // 3. Onboard profile if not onboarded
  if (!user.onboardingCompleted) {
    const onboardRes = await request('/users/me/onboarding', {
      method: 'PATCH',
      token,
      body: {
        displayName: name,
        locality,
        city,
        state: 'Karnataka',
        countryCode: 'IN',
      },
    });
    if (onboardRes.status !== 200) {
      throw new Error(`Onboarding failed for ${phone}: ${JSON.stringify(onboardRes.data)}`);
    }
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

async function runVerification() {
  console.log('====================================================');
  console.log('🌍 AASPAAS PHASE 4 — NEARBY RUNTIME VERIFICATION');
  console.log('====================================================\n');

  // STEP 1: Authenticate Users in different localities
  console.log('1. Authenticating test users...');
  const userKoramangala = await authenticateUser(
    '+919876543210',
    'Koramangala Resident',
    'Koramangala',
    'Bengaluru',
  );
  assert(userKoramangala.token, 'User 1 (Koramangala) authenticated');

  const userIndiranagar = await authenticateUser(
    '+919876543211',
    'Indiranagar Resident',
    'Indiranagar',
    'Bengaluru',
  );
  assert(userIndiranagar.token, 'User 2 (Indiranagar) authenticated');

  const userDelhi = await authenticateUser(
    '+919876543212',
    'Delhi Resident',
    'Connaught Place',
    'Delhi',
  );
  assert(userDelhi.token, 'User 3 (Delhi) authenticated');

  // STEP 2: Create Posts with safe locality centroids
  console.log('\n2. Creating Posts stamped with locality centroids...');
  const timestamp = Date.now();

  const postKoramangalaRes = await request('/feed/posts', {
    method: 'POST',
    token: userKoramangala.token,
    body: {
      content: `[Nearby Test ${timestamp}] Koramangala 5th Block community cleanup drive this weekend!`,
      category: 'announcement',
    },
  });
  assert(postKoramangalaRes.status === 201, 'Post created in Koramangala');
  const postKoramangalaId = postKoramangalaRes.data.data.id;

  const postIndiranagarRes = await request('/feed/posts', {
    method: 'POST',
    token: userIndiranagar.token,
    body: {
      content: `[Nearby Test ${timestamp}] Indiranagar 100ft Road power maintenance notice`,
      category: 'alert',
    },
  });
  assert(postIndiranagarRes.status === 201, 'Post created in Indiranagar');
  const postIndiranagarId = postIndiranagarRes.data.data.id;

  const postDelhiRes = await request('/feed/posts', {
    method: 'POST',
    token: userDelhi.token,
    body: {
      content: `[Nearby Test ${timestamp}] Connaught Place metro station exit 3 renovation`,
      category: 'general',
    },
  });
  assert(postDelhiRes.status === 201, 'Post created in Delhi');
  const postDelhiId = postDelhiRes.data.data.id;

  // STEP 3: Query Nearby from Koramangala Centroid (12.9352, 77.6245) with Radius = 1 km
  console.log('\n3. Querying GET /api/v1/nearby/posts with radius = 1 km from Koramangala (12.9352, 77.6245)...');
  const nearby1kmRes = await request('/nearby/posts?latitude=12.9352&longitude=77.6245&radius=1', {
    method: 'GET',
    token: userKoramangala.token,
  });
  assert(nearby1kmRes.status === 200, 'GET /nearby/posts status 200');
  const data1km = nearby1kmRes.data.data;
  assert(data1km.radiusKm === 1, 'Response confirms radiusKm is 1');
  const items1km = data1km.items || data1km.posts;
  assert(Array.isArray(items1km), 'Response contains items array');

  const foundKoramangalaIn1km = items1km.find((p) => p.id === postKoramangalaId);
  assert(foundKoramangalaIn1km !== undefined, 'Koramangala post is included in 1 km radius');
  assert(foundKoramangalaIn1km.distance === 'Nearby', `Distance is formatted as "Nearby" (< 100m from centroid): got "${foundKoramangalaIn1km.distance}"`);
  assert(foundKoramangalaIn1km.distanceMeters <= 100, `DistanceMeters <= 100: got ${foundKoramangalaIn1km.distanceMeters}`);

  const foundIndiranagarIn1km = items1km.find((p) => p.id === postIndiranagarId);
  assert(foundIndiranagarIn1km === undefined, 'Indiranagar post (~5.1 km away) is correctly EXCLUDED from 1 km radius');

  const foundDelhiIn1km = items1km.find((p) => p.id === postDelhiId);
  assert(foundDelhiIn1km === undefined, 'Delhi post (> 1700 km away) is correctly EXCLUDED from 1 km radius');

  // STEP 4: Query Nearby from Koramangala Centroid with Radius = 10 km
  console.log('\n4. Expanding radius to 10 km from Koramangala (12.9352, 77.6245)...');
  const nearby10kmRes = await request('/nearby/posts?latitude=12.9352&longitude=77.6245&radius=10', {
    method: 'GET',
    token: userKoramangala.token,
  });
  assert(nearby10kmRes.status === 200, 'GET /nearby/posts status 200 with radius 10');
  const data10km = nearby10kmRes.data.data;
  assert(data10km.radiusKm === 10, 'Response confirms radiusKm is 10');
  const items10km = data10km.items || data10km.posts;

  const foundKoramangalaIn10km = items10km.find((p) => p.id === postKoramangalaId);
  assert(foundKoramangalaIn10km !== undefined, 'Koramangala post is included in 10 km radius');

  const foundIndiranagarIn10km = items10km.find((p) => p.id === postIndiranagarId);
  assert(foundIndiranagarIn10km !== undefined, 'Indiranagar post is NOW INCLUDED in 10 km radius');
  console.log(`  ℹ️ Indiranagar post distance formatted: "${foundIndiranagarIn10km.distance}", meters: ${foundIndiranagarIn10km.distanceMeters}`);
  assert(foundIndiranagarIn10km.distanceMeters >= 4000 && foundIndiranagarIn10km.distanceMeters <= 7000, 'Indiranagar distance is ~5 km');
  assert(foundIndiranagarIn10km.distance.includes('km away'), `Indiranagar distance string has "km away": got "${foundIndiranagarIn10km.distance}"`);

  const foundDelhiIn10km = items10km.find((p) => p.id === postDelhiId);
  assert(foundDelhiIn10km === undefined, 'Delhi post is still EXCLUDED in 10 km radius');

  // STEP 5: Privacy Verification
  console.log('\n5. Verifying Location & Author Privacy Guarantees...');
  for (const post of items10km) {
    assert(post.location === undefined, `Post ${post.id}: location column is NOT exposed`);
    assert(post.latitude === undefined, `Post ${post.id}: latitude is NOT exposed`);
    assert(post.longitude === undefined, `Post ${post.id}: longitude is NOT exposed`);
    assert(post.author.phone === undefined, `Post ${post.id}: author.phone is NOT exposed`);
    assert(post.author.email === undefined, `Post ${post.id}: author.email is NOT exposed`);
    assert(typeof post.distance === 'string', `Post ${post.id}: distance is privacy-safe string`);
    assert(typeof post.distanceMeters === 'number', `Post ${post.id}: distanceMeters is present`);
  }
  console.log('  🔒 All privacy checks passed! Zero raw coordinates, zero phone numbers exposed.');

  // STEP 6: Input Validation & Security Bounds
  console.log('\n6. Testing Input Validation & Security Bounds...');
  // 6a: Missing latitude
  const missingLatRes = await request('/nearby/posts?longitude=77.6245', {
    method: 'GET',
    token: userKoramangala.token,
  });
  assert(missingLatRes.status === 400, 'Missing latitude returns 400 Bad Request');

  // 6b: Invalid latitude (> 90)
  const invalidLatRes = await request('/nearby/posts?latitude=95.0&longitude=77.6245', {
    method: 'GET',
    token: userKoramangala.token,
  });
  assert(invalidLatRes.status === 400, 'Latitude > 90 returns 400 Bad Request');

  // 6c: Invalid radius (> 20 km max limit)
  const excessiveRadiusRes = await request('/nearby/posts?latitude=12.9352&longitude=77.6245&radius=50', {
    method: 'GET',
    token: userKoramangala.token,
  });
  assert(excessiveRadiusRes.status === 400, 'Radius > 20 km returns 400 Bad Request');

  // 6d: Unauthenticated request
  const unauthRes = await request('/nearby/posts?latitude=12.9352&longitude=77.6245', {
    method: 'GET',
  });
  assert(unauthRes.status === 401, 'Unauthenticated request returns 401 Unauthorized');

  // STEP 7: Category Filtering
  console.log('\n7. Testing Category Filtering...');
  const categoryAlertRes = await request('/nearby/posts?latitude=12.9352&longitude=77.6245&radius=10&category=alert', {
    method: 'GET',
    token: userKoramangala.token,
  });
  const alertPosts = categoryAlertRes.data.data.items || categoryAlertRes.data.data.posts;
  for (const p of alertPosts) {
    assert(p.category === 'alert', `Post ${p.id} category is alert`);
  }

  // STEP 8: Cleanup test posts
  console.log('\n8. Cleaning up test posts...');
  await request(`/feed/posts/${postKoramangalaId}`, { method: 'DELETE', token: userKoramangala.token });
  await request(`/feed/posts/${postIndiranagarId}`, { method: 'DELETE', token: userIndiranagar.token });
  await request(`/feed/posts/${postDelhiId}`, { method: 'DELETE', token: userDelhi.token });
  console.log('  🧹 Cleaned up test posts.');

  console.log('\n====================================================');
  console.log('🎉 PHASE 4 — NEARBY RUNTIME VERIFICATION SUCCESSFUL');
  console.log('====================================================');
}

runVerification().catch((err) => {
  console.error('Unhandled runtime verification error:', err);
  process.exit(1);
});

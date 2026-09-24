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
          const payload = (json && typeof json === 'object' && 'data' in json) ? json.data : json;
          resolve({ status: res.statusCode, data: payload, envelope: json });
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

function assertOwnerPrivacy(owner, label) {
  if (!owner) return;
  const jsonStr = JSON.stringify(owner);
  const sensitiveProps = ['password', 'passwordHash', 'refreshToken', 'refreshTokenHash', 'secret'];
  for (const prop of sensitiveProps) {
    if (jsonStr.includes(`"${prop}"`)) {
      throw new Error(`[PRIVACY VIOLATION] Sensitive property "${prop}" leaked in ${label}: ${jsonStr}`);
    }
  }
}

async function authenticateUser(phone, name, locality, city) {
  const otpRes = await request('POST', '/auth/otp/request', { phoneNumber: phone });
  if (otpRes.status !== 200) throw new Error(`OTP request failed for ${phone}: ${JSON.stringify(otpRes.data)}`);
  const devOtp = otpRes.data?.devOtp ?? otpRes.envelope?.data?.devOtp;

  const verifyRes = await request('POST', '/auth/otp/verify', {
    phoneNumber: phone,
    otp: devOtp,
    deviceMetadata: { platform: 'Android 15', model: 'Pixel 10 Pro' },
  });
  if (verifyRes.status !== 200) throw new Error(`OTP verify failed for ${phone}: ${JSON.stringify(verifyRes.data)}`);
  const token = verifyRes.data?.tokens?.accessToken ?? verifyRes.envelope?.data?.tokens?.accessToken;
  const user = verifyRes.data?.user ?? verifyRes.envelope?.data?.user;

  if (!user.onboardingCompleted) {
    await request('PATCH', '/users/me/onboarding', {
      displayName: name,
      locality,
      city,
      state: 'Karnataka',
      countryCode: 'IN',
    }, token);
  }

  return { token, user };
}

async function runPhase7Verification() {
  console.log('================================================================');
  console.log('  AASPAAS PHASE 7: BUSINESSES & SERVICES RUNTIME VERIFICATION   ');
  console.log('================================================================\n');

  // 1. HEALTH CHECK
  console.log('--- 1. INFRASTRUCTURE HEALTH CHECK ---');
  const health = await request('GET', '/health');
  console.log(`[Health] Status: ${health.status}, Response:`, JSON.stringify(health.data));
  if (health.status !== 200 || health.data.database !== 'connected' || health.data.redis !== 'connected') {
    throw new Error('Health check failed! Ensure Postgres and Redis are running.');
  }

  // 2. AUTHENTICATE TEST USERS
  console.log('\n--- 2. AUTHENTICATING TEST USERS ---');
  const numA = Math.floor(10000000 + Math.random() * 90000000).toString();
  const numB = Math.floor(10000000 + Math.random() * 90000000).toString();
  const userA = await authenticateUser(`+9198${numA.slice(0, 8)}`, 'Ramesh Stores', 'Indiranagar', 'Bengaluru');
  console.log(`[User A - Merchant/Provider] Authenticated ID: ${userA.user.id}`);

  const userB = await authenticateUser(`+9197${numB.slice(0, 8)}`, 'Kavita Neighbor', 'Koramangala', 'Bengaluru');
  console.log(`[User B - Customer/Neighbor] Authenticated ID: ${userB.user.id}`);

  // 3. CATEGORIES ENDPOINTS
  console.log('\n--- 3. CATEGORY LISTINGS METADATA ---');
  const bCategories = await request('GET', '/businesses/categories', null, userA.token);
  console.log(`[Business Categories] Count: ${bCategories.data.length}, First:`, bCategories.data[0]);
  if (!bCategories.data.some(c => c.id === 'food_dining')) {
    throw new Error('Missing expected business category food_dining');
  }

  const sCategories = await request('GET', '/services/categories', null, userA.token);
  console.log(`[Service Categories] Count: ${sCategories.data.length}, First:`, sCategories.data[0]);
  if (!sCategories.data.some(c => c.id === 'home_repair')) {
    throw new Error('Missing expected service category home_repair');
  }

  // 4. BUSINESS CRUD & LIFECYCLE (User A)
  console.log('\n--- 4. USER A: CREATE & MANAGE BUSINESS ---');
  const businessPayload = {
    name: `Indiranagar Fresh & Organic ${Date.now().toString().slice(-4)}`,
    description: 'Fresh local farm produce, dairy, bakery items, and artisanal filter coffee.',
    category: 'food_dining',
    address: '124, 100ft Road, 12th Main',
    locality: 'Indiranagar',
    city: 'Bengaluru',
    state: 'Karnataka',
    latitude: 12.9716,
    longitude: 77.6412,
    contactPhone: '+919876543210',
    contactEmail: 'contact@freshorganic.local',
    website: 'https://freshorganic.local',
    operatingHours: {
      monday: { isClosed: false, intervals: [{ open: '08:00', close: '22:00' }] },
      tuesday: { isClosed: false, intervals: [{ open: '08:00', close: '22:00' }] },
      wednesday: { isClosed: false, intervals: [{ open: '08:00', close: '22:00' }] },
      thursday: { isClosed: false, intervals: [{ open: '08:00', close: '22:00' }] },
      friday: { isClosed: false, intervals: [{ open: '08:00', close: '22:00' }] },
      saturday: { isClosed: false, intervals: [{ open: '08:00', close: '22:00' }] },
      sunday: { isClosed: true, intervals: [] },
    },
    images: [
      { url: 'https://images.unsplash.com/photo-1542838132-92c53300491e', displayOrder: 0 },
      { url: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58', displayOrder: 1 },
    ],
    services: [
      { name: 'Cold Pressed Coconut Oil', startingPrice: 240 },
      { name: 'Fresh A2 Cow Milk', startingPrice: 75 },
    ],
  };

  const createBusinessRes = await request('POST', '/businesses', businessPayload, userA.token);
  console.log(`[Create Business] Status: ${createBusinessRes.status}`);
  if (createBusinessRes.status !== 201) {
    throw new Error(`Failed to create business: ${JSON.stringify(createBusinessRes.data)}`);
  }
  const business = createBusinessRes.data;
  console.log(`[Created Business] ID: ${business.id}, Name: "${business.name}", Slug: "${business.slug}", Status: ${business.status}`);
  assertOwnerPrivacy(business.owner, 'Created Business Owner');

  // Verify business by ID
  const getBusinessRes = await request('GET', `/businesses/${business.id}`, null, userB.token);
  console.log(`[Get Business] Status: ${getBusinessRes.status}, Open Status:`, getBusinessRes.data.operatingStatus);
  if (getBusinessRes.status !== 200 || !getBusinessRes.data.operatingStatus) {
    throw new Error(`Failed to fetch business by ID: ${JSON.stringify(getBusinessRes.data)}`);
  }

  // Update business
  const updateBusinessRes = await request('PATCH', `/businesses/${business.id}`, {
    description: 'Updated description: Bengaluru premier zero-waste organic grocery store.',
  }, userA.token);
  console.log(`[Update Business] Status: ${updateBusinessRes.status}`);
  if (updateBusinessRes.status !== 200 || !updateBusinessRes.data.description.includes('zero-waste')) {
    throw new Error('Business update failed');
  }

  // 5. SERVICE CRUD & LIFECYCLE (User A)
  console.log('\n--- 5. USER A: CREATE & MANAGE SERVICE LISTING ---');
  const servicePayload = {
    title: `Expert Home Electrician & Rewiring ${Date.now().toString().slice(-4)}`,
    description: 'Certified licensed electrical technician for homes, offices, appliances, and inverter setups.',
    category: 'home_repair',
    locality: 'Indiranagar',
    city: 'Bengaluru',
    state: 'Karnataka',
    latitude: 12.9716,
    longitude: 77.6412,
    serviceRadiusKm: 15,
    contactPhone: '+919876543210',
    contactEmail: 'tech@sparkelectric.local',
    experienceYears: 8,
    availability: 'Mon - Sat (9 AM - 8 PM)',
    startingPrice: 399,
  };

  const createServiceRes = await request('POST', '/services', servicePayload, userA.token);
  console.log(`[Create Service] Status: ${createServiceRes.status}`);
  if (createServiceRes.status !== 201) {
    throw new Error(`Failed to create service: ${JSON.stringify(createServiceRes.data)}`);
  }
  const service = createServiceRes.data;
  console.log(`[Created Service] ID: ${service.id}, Title: "${service.title}", Price: ₹${service.startingPrice}`);
  assertOwnerPrivacy(service.provider, 'Created Service Provider');

  // Verify service by ID
  const getServiceRes = await request('GET', `/services/${service.id}`, null, userB.token);
  console.log(`[Get Service] Status: ${getServiceRes.status}, Provider Name: "${getServiceRes.data.owner?.displayName}"`);
  if (getServiceRes.status !== 200) {
    throw new Error('Failed to fetch service listing by ID');
  }

  // 6. POSTGIS SPATIAL SEARCH & FILTERS (User B from Koramangala)
  console.log('\n--- 6. USER B: SPATIAL SEARCH & HYPERLOCAL DISCOVERY ---');
  const koramangalaLat = 12.9352;
  const koramangalaLng = 77.6245;

  // Search businesses nearby
  const nearbyBusinesses = await request(
    'GET',
    `/businesses?latitude=${koramangalaLat}&longitude=${koramangalaLng}&radius=10&category=food_dining`,
    null,
    userB.token
  );
  console.log(`[Search Businesses] Status: ${nearbyBusinesses.status}, Found ${nearbyBusinesses.data.items?.length ?? 0} businesses within 10km`);
  const foundBusiness = nearbyBusinesses.data.items?.find(b => b.id === business.id);
  if (!foundBusiness) {
    throw new Error(`Created business not discovered within 10km PostGIS query. Status: ${nearbyBusinesses.status}, Body: ${JSON.stringify(nearbyBusinesses.data)}`);
  }
  console.log(`[Business Discovery Match] "${foundBusiness.name}", Distance: ${foundBusiness.distance}`);

  // Search services nearby
  const nearbyServices = await request(
    'GET',
    `/services?latitude=${koramangalaLat}&longitude=${koramangalaLng}&radius=15&category=home_repair`,
    null,
    userB.token
  );
  console.log(`[Search Services] Status: ${nearbyServices.status}, Found ${nearbyServices.data.items?.length ?? 0} services within 15km`);
  const foundService = nearbyServices.data.items?.find(s => s.id === service.id);
  if (!foundService) {
    throw new Error(`Created service not discovered within 15km PostGIS query. Status: ${nearbyServices.status}, Body: ${JSON.stringify(nearbyServices.data)}`);
  }
  console.log(`[Service Discovery Match] "${foundService.title}", Distance: ${foundService.distance}`);

  // 7. FAVORITES & COUNTERS
  console.log('\n--- 7. FAVORITES TOGGLING & COUNTERS ---');
  const favBRes = await request('POST', `/businesses/${business.id}/favorite`, null, userB.token);
  console.log(`[Favorite Business] Status: ${favBRes.status}, Res:`, favBRes.data);
  if (favBRes.status !== 200 || favBRes.data.isFavorited !== true || favBRes.data.favoriteCount < 1) {
    throw new Error('Favorite business failed');
  }

  const unfavBRes = await request('DELETE', `/businesses/${business.id}/favorite`, null, userB.token);
  console.log(`[Unfavorite Business] Status: ${unfavBRes.status}, Res:`, unfavBRes.data);
  if (unfavBRes.status !== 200 || unfavBRes.data.isFavorited !== false) {
    throw new Error('Unfavorite business failed');
  }

  const favSRes = await request('POST', `/services/${service.id}/favorite`, null, userB.token);
  console.log(`[Favorite Service] Status: ${favSRes.status}, Res:`, favSRes.data);
  if (favSRes.status !== 200 || favSRes.data.isFavorited !== true) {
    throw new Error('Favorite service failed');
  }

  // 8. SAFETY & MODERATION REPORTING
  console.log('\n--- 8. SAFETY & COMMUNITY REPORTING ---');
  const reportB = await request('POST', `/businesses/${business.id}/report`, {
    reason: 'incorrect_info',
    details: 'Store timings on Monday are listed differently at physical shopfront.',
  }, userB.token);
  console.log(`[Report Business] Status: ${reportB.status}, Success: ${reportB.data?.success}`);
  if (reportB.status !== 200 || reportB.data?.success !== true) throw new Error('Failed to report business');

  // Duplicate report test
  const dupReportB = await request('POST', `/businesses/${business.id}/report`, {
    reason: 'spam',
  }, userB.token);
  console.log(`[Duplicate Report Business] Status: ${dupReportB.status} (Expected 409)`);
  if (dupReportB.status !== 409) throw new Error('Duplicate report did not return 409');

  const reportS = await request('POST', `/services/${service.id}/report`, {
    reason: 'spam',
    details: 'Provider phone is constantly busy.',
  }, userB.token);
  console.log(`[Report Service] Status: ${reportS.status}, Success: ${reportS.data?.success}`);
  if (reportS.status !== 200 || reportS.data?.success !== true) throw new Error('Failed to report service');

  // 9. AUTHORIZATION & OWNER ACCESS CONTROL
  console.log('\n--- 9. AUTHORIZATION CHECKS ---');
  const unauthorizedEdit = await request('PATCH', `/businesses/${business.id}`, {
    name: 'Hacked Store Name',
  }, userB.token);
  console.log(`[Unauthorized Business Edit] Status: ${unauthorizedEdit.status} (Expected 403)`);
  if (unauthorizedEdit.status !== 403) throw new Error('Unauthorized edit did not return 403');

  const unauthorizedServiceDelete = await request('DELETE', `/services/${service.id}`, null, userB.token);
  console.log(`[Unauthorized Service Delete] Status: ${unauthorizedServiceDelete.status} (Expected 403)`);
  if (unauthorizedServiceDelete.status !== 403) throw new Error('Unauthorized delete did not return 403');

  // User A my-businesses & my-services
  const myBusinesses = await request('GET', '/businesses/me', null, userA.token);
  console.log(`[User A My Businesses] Count: ${myBusinesses.data.items?.length}`);
  if (!myBusinesses.data.items?.some(b => b.id === business.id)) {
    throw new Error('My businesses did not return owned business');
  }

  const myServices = await request('GET', '/services/me', null, userA.token);
  console.log(`[User A My Services] Count: ${myServices.data.items?.length}`);
  if (!myServices.data.items?.some(s => s.id === service.id)) {
    throw new Error('My services did not return owned service');
  }

  // 10. PHASES 0-6 REGRESSION CHECKS
  console.log('\n--- 10. PRESERVED PHASES 0-6 REGRESSION VERIFICATION ---');
  const feedRes = await request('GET', '/feed/posts', null, userB.token);
  console.log(`[Phase 3 Feed] Status: ${feedRes.status}, Posts count: ${feedRes.data.items?.length ?? 0}`);
  if (feedRes.status !== 200) throw new Error('Feed regression detected');

  const nearbyRes = await request('GET', `/nearby/posts?latitude=${koramangalaLat}&longitude=${koramangalaLng}&radius=10`, null, userB.token);
  console.log(`[Phase 4 Nearby] Status: ${nearbyRes.status}, Nearby count: ${nearbyRes.data.items?.length ?? 0}`);
  if (nearbyRes.status !== 200) throw new Error('Nearby regression detected');

  const commRes = await request('GET', '/communities', null, userB.token);
  console.log(`[Phase 5 Communities] Status: ${commRes.status}, Communities count: ${commRes.data.items?.length ?? 0}`);
  if (commRes.status !== 200) throw new Error('Communities regression detected');

  const mktRes = await request('GET', '/marketplace/listings', null, userB.token);
  console.log(`[Phase 6 Marketplace] Status: ${mktRes.status}, Listings count: ${mktRes.data.items?.length ?? 0}`);
  if (mktRes.status !== 200) throw new Error('Marketplace regression detected');

  console.log('\n================================================================');
  console.log('  PHASE 7 BUSINESSES & SERVICES VERIFICATION COMPLETE: PASSED!  ');
  console.log('================================================================\n');
}

runPhase7Verification().catch((err) => {
  console.error('\n❌ [Phase 7 Verification Error]:', err);
  process.exit(1);
});

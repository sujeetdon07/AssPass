import http from 'node:http';
import { evaluateOperatingStatus } from '../dist/modules/businesses/utils/operating-hours.util.js';

const BASE_URL = 'http://localhost:3000/api/v1';

async function request(method, path, body = null, token = null) {
  const startTime = Date.now();
  return new Promise((resolve, reject) => {
    const url = new URL(`${BASE_URL}${path}`);
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(url, { method, headers }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        const durationMs = Date.now() - startTime;
        try {
          const json = JSON.parse(data);
          const payload = (json && typeof json === 'object' && 'data' in json) ? json.data : json;
          resolve({ status: res.statusCode, data: payload, envelope: json, durationMs });
        } catch {
          resolve({ status: res.statusCode, text: data, durationMs });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
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

async function main() {
  console.log('================================================================');
  console.log('   AASPAAS PHASE 7 FULL RUNTIME COMPREHENSIVE VERIFICATION     ');
  console.log('================================================================\n');

  const performanceMetrics = [];
  function recordMetric(name, durationMs) {
    performanceMetrics.push({ name, durationMs });
  }

  // -------------------------------------------------------------
  // STEP 1 & 3: HEALTH CHECK
  // -------------------------------------------------------------
  console.log('=== STEP 1 & 3: HEALTH CHECK ===');
  const health = await request('GET', '/health');
  recordMetric('GET /health', health.durationMs);
  console.log(`[Health] Status: ${health.status}, Response:`, JSON.stringify(health.data), `(${health.durationMs}ms)`);
  if (health.status !== 200 || health.data.database !== 'connected' || health.data.redis !== 'connected') {
    throw new Error('Health check failed: Postgres or Redis not healthy');
  }

  // -------------------------------------------------------------
  // USER SETUP
  // -------------------------------------------------------------
  console.log('\n=== SETTING UP AUTHENTICATED USERS ===');
  const randA = Math.floor(10000000 + Math.random() * 90000000).toString();
  const randB = Math.floor(10000000 + Math.random() * 90000000).toString();
  const userA = await authenticateUser(`+9198${randA.slice(0, 8)}`, 'Owner User A', 'Indiranagar', 'Bengaluru');
  const userB = await authenticateUser(`+9197${randB.slice(0, 8)}`, 'Neighbor User B', 'Koramangala', 'Bengaluru');
  console.log(`User A (Owner): ${userA.user.id}`);
  console.log(`User B (Neighbor/Non-owner): ${userB.user.id}`);

  // -------------------------------------------------------------
  // STEP 3: BACKEND API VERIFICATION (ALL 20 ENDPOINTS + DTO + 401/403/409)
  // -------------------------------------------------------------
  console.log('\n=== STEP 3: BACKEND API ENDPOINT VERIFICATION ===');

  // Business 1: GET /api/v1/businesses/categories
  const bCats = await request('GET', '/businesses/categories', null, userA.token);
  recordMetric('GET /businesses/categories', bCats.durationMs);
  console.log(`✓ GET /businesses/categories [${bCats.status}] -> ${bCats.data.length} categories (${bCats.durationMs}ms)`);
  if (bCats.status !== 200 || bCats.data.length < 5) throw new Error('Failed GET /businesses/categories');

  // Service 1: GET /api/v1/services/categories
  const sCats = await request('GET', '/services/categories', null, userA.token);
  recordMetric('GET /services/categories', sCats.durationMs);
  console.log(`✓ GET /services/categories [${sCats.status}] -> ${sCats.data.length} categories (${sCats.durationMs}ms)`);
  if (sCats.status !== 200 || sCats.data.length < 5) throw new Error('Failed GET /services/categories');

  // Business 2: POST /api/v1/businesses - Unauthenticated 401
  const unauthB = await request('POST', '/businesses', { name: 'No Auth Store' });
  console.log(`✓ POST /businesses (unauthenticated) [${unauthB.status}] -> Protected by JWT Guard`);
  if (unauthB.status !== 401) throw new Error('Unauthenticated POST /businesses did not return 401');

  // Business 3: POST /api/v1/businesses - DTO Validation (missing required fields)
  const badDtoB = await request('POST', '/businesses', { name: '' }, userA.token);
  console.log(`✓ POST /businesses (invalid DTO) [${badDtoB.status}] -> DTO Validation working`);
  if (badDtoB.status !== 400) throw new Error('Invalid DTO did not return 400');

  // Business 4: POST /api/v1/businesses - Successful Creation
  const newBusinessPayload = {
    name: `Indiranagar Gourmet Mart ${Date.now().toString().slice(-4)}`,
    description: 'Artisanal cheese, sourdough, cold press juices, and organic produce.',
    category: 'food_dining',
    address: '42, 100 Feet Rd, Indiranagar',
    locality: 'Indiranagar',
    city: 'Bengaluru',
    state: 'Karnataka',
    latitude: 12.9716, // Indiranagar
    longitude: 77.6412,
    contactPhone: '+919876543210',
    contactEmail: 'hello@indiranagarmart.local',
    website: 'https://indiranagarmart.local',
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
    ],
    services: [
      { name: 'Organic Cold Press Juice', startingPrice: 150 },
    ],
  };
  const createB = await request('POST', '/businesses', newBusinessPayload, userA.token);
  recordMetric('POST /businesses', createB.durationMs);
  console.log(`✓ POST /businesses [${createB.status}] -> Created ID: ${createB.data.id} (${createB.durationMs}ms)`);
  if (createB.status !== 201) throw new Error('Failed POST /businesses');
  const business = createB.data;

  // Business 5: GET /api/v1/businesses/me
  const myB = await request('GET', '/businesses/me', null, userA.token);
  recordMetric('GET /businesses/me', myB.durationMs);
  console.log(`✓ GET /businesses/me [${myB.status}] -> ${myB.data.items?.length} items (${myB.durationMs}ms)`);
  if (myB.status !== 200 || !myB.data.items?.some(i => i.id === business.id)) throw new Error('Failed GET /businesses/me');

  // Business 6: GET /api/v1/businesses/:id
  const getB = await request('GET', `/businesses/${business.id}`, null, userB.token);
  recordMetric('GET /businesses/:id', getB.durationMs);
  console.log(`✓ GET /businesses/:id [${getB.status}] -> Operating status: ${getB.data.operatingStatus?.status} (${getB.durationMs}ms)`);
  if (getB.status !== 200 || getB.data.name !== business.name) throw new Error('Failed GET /businesses/:id');

  // Business 7: PATCH /api/v1/businesses/:id - 403 Forbidden for non-owner
  const patchB403 = await request('PATCH', `/businesses/${business.id}`, { name: 'Hacked Name' }, userB.token);
  console.log(`✓ PATCH /businesses/:id (non-owner) [${patchB403.status}] -> 403 Forbidden protection`);
  if (patchB403.status !== 403) throw new Error('Non-owner PATCH did not return 403');

  // Business 8: PATCH /api/v1/businesses/:id - 200 OK for owner
  const patchBOk = await request('PATCH', `/businesses/${business.id}`, { description: 'Updated gourmet selection' }, userA.token);
  recordMetric('PATCH /businesses/:id', patchBOk.durationMs);
  console.log(`✓ PATCH /businesses/:id (owner) [${patchBOk.status}] -> Updated description (${patchBOk.durationMs}ms)`);
  if (patchBOk.status !== 200 || !patchBOk.data.description.includes('Updated gourmet selection')) throw new Error('Owner PATCH failed');

  // Business 9: POST /api/v1/businesses/:id/favorite
  const favB = await request('POST', `/businesses/${business.id}/favorite`, null, userB.token);
  recordMetric('POST /businesses/:id/favorite', favB.durationMs);
  console.log(`✓ POST /businesses/:id/favorite [${favB.status}] -> isFavorited: ${favB.data.isFavorited}, count: ${favB.data.favoriteCount} (${favB.durationMs}ms)`);
  if (favB.status !== 200 || favB.data.isFavorited !== true || favB.data.favoriteCount < 1) throw new Error('Failed favorite business');

  // Duplicate favorite test (should remain favorited)
  const dupFavB = await request('POST', `/businesses/${business.id}/favorite`, null, userB.token);
  console.log(`✓ POST /businesses/:id/favorite (duplicate) [${dupFavB.status}] -> Idempotent handling (favoriteCount: ${dupFavB.data.favoriteCount})`);
  if (dupFavB.status !== 200 || dupFavB.data.favoriteCount !== favB.data.favoriteCount) throw new Error('Duplicate favorite altered counter');

  // Business 10: DELETE /api/v1/businesses/:id/favorite
  const unFavB = await request('DELETE', `/businesses/${business.id}/favorite`, null, userB.token);
  recordMetric('DELETE /businesses/:id/favorite', unFavB.durationMs);
  console.log(`✓ DELETE /businesses/:id/favorite [${unFavB.status}] -> isFavorited: ${unFavB.data.isFavorited}, count: ${unFavB.data.favoriteCount} (${unFavB.durationMs}ms)`);
  if (unFavB.status !== 200 || unFavB.data.isFavorited !== false || unFavB.data.favoriteCount !== favB.data.favoriteCount - 1) throw new Error('Failed unfavorite business');

  // Business 11: POST /api/v1/businesses/:id/report - Self report block (400)
  const selfRepB = await request('POST', `/businesses/${business.id}/report`, { reason: 'spam' }, userA.token);
  console.log(`✓ POST /businesses/:id/report (owner self-report) [${selfRepB.status}] -> Self-report blocked`);
  if (selfRepB.status !== 400) throw new Error('Self report business did not return 400');

  // Business 12: POST /api/v1/businesses/:id/report - Successful report by User B
  const repB = await request('POST', `/businesses/${business.id}/report`, { reason: 'incorrect_info', details: 'Wrong closing time' }, userB.token);
  recordMetric('POST /businesses/:id/report', repB.durationMs);
  console.log(`✓ POST /businesses/:id/report (User B) [${repB.status}] -> Reported successfully (${repB.durationMs}ms)`);
  if (repB.status !== 200) throw new Error('Failed report business');

  // Business 13: POST /api/v1/businesses/:id/report - Duplicate report conflict (409)
  const dupRepB = await request('POST', `/businesses/${business.id}/report`, { reason: 'spam' }, userB.token);
  console.log(`✓ POST /businesses/:id/report (duplicate) [${dupRepB.status}] -> 409 Conflict handled`);
  if (dupRepB.status !== 409) throw new Error('Duplicate report did not return 409 Conflict');

  // Service 2: POST /api/v1/services - Unauthenticated 401
  const unauthS = await request('POST', '/services', { title: 'No Auth Service' });
  console.log(`✓ POST /services (unauthenticated) [${unauthS.status}] -> Protected by JWT Guard`);
  if (unauthS.status !== 401) throw new Error('Unauthenticated POST /services did not return 401');

  // Service 3: POST /api/v1/services - Successful Creation
  const newServicePayload = {
    title: `Precision AC Repair & Service ${Date.now().toString().slice(-4)}`,
    description: 'Expert residential and commercial split & inverter AC servicing, gas refill, and installation.',
    category: 'home_repair',
    locality: 'Indiranagar',
    city: 'Bengaluru',
    state: 'Karnataka',
    latitude: 12.9716,
    longitude: 77.6412,
    serviceRadiusKm: 20,
    contactPhone: '+919876543210',
    contactEmail: 'ac@precisioncool.local',
    experienceYears: 6,
    availability: 'Mon - Sun (8 AM - 9 PM)',
    startingPrice: 499,
  };
  const createS = await request('POST', '/services', newServicePayload, userA.token);
  recordMetric('POST /services', createS.durationMs);
  console.log(`✓ POST /services [${createS.status}] -> Created ID: ${createS.data.id} (${createS.durationMs}ms)`);
  if (createS.status !== 201) throw new Error('Failed POST /services');
  const service = createS.data;

  // Service 4: GET /api/v1/services/me
  const myS = await request('GET', '/services/me', null, userA.token);
  recordMetric('GET /services/me', myS.durationMs);
  console.log(`✓ GET /services/me [${myS.status}] -> ${myS.data.items?.length} items (${myS.durationMs}ms)`);
  if (myS.status !== 200 || !myS.data.items?.some(i => i.id === service.id)) throw new Error('Failed GET /services/me');

  // Service 5: GET /api/v1/services/:id
  const getS = await request('GET', `/services/${service.id}`, null, userB.token);
  recordMetric('GET /services/:id', getS.durationMs);
  console.log(`✓ GET /services/:id [${getS.status}] -> Provider: ${getS.data.owner?.displayName} (${getS.durationMs}ms)`);
  if (getS.status !== 200 || getS.data.title !== service.title) throw new Error('Failed GET /services/:id');

  // Service 6: PATCH /api/v1/services/:id - 403 Forbidden for non-owner
  const patchS403 = await request('PATCH', `/services/${service.id}`, { title: 'Hacked Service' }, userB.token);
  console.log(`✓ PATCH /services/:id (non-owner) [${patchS403.status}] -> 403 Forbidden protection`);
  if (patchS403.status !== 403) throw new Error('Non-owner PATCH did not return 403');

  // Service 7: PATCH /api/v1/services/:id - 200 OK for owner
  const patchSOk = await request('PATCH', `/services/${service.id}`, { startingPrice: 549 }, userA.token);
  recordMetric('PATCH /services/:id', patchSOk.durationMs);
  console.log(`✓ PATCH /services/:id (owner) [${patchSOk.status}] -> Updated price: ₹${patchSOk.data.startingPrice} (${patchSOk.durationMs}ms)`);
  if (patchSOk.status !== 200 || Number(patchSOk.data.startingPrice) !== 549) throw new Error('Owner PATCH failed');

  // Service 8: POST /api/v1/services/:id/favorite
  const favS = await request('POST', `/services/${service.id}/favorite`, null, userB.token);
  recordMetric('POST /services/:id/favorite', favS.durationMs);
  console.log(`✓ POST /services/:id/favorite [${favS.status}] -> isFavorited: ${favS.data.isFavorited} (${favS.durationMs}ms)`);
  if (favS.status !== 200 || favS.data.isFavorited !== true) throw new Error('Failed favorite service');

  // Duplicate service favorite test
  const dupFavS = await request('POST', `/services/${service.id}/favorite`, null, userB.token);
  console.log(`✓ POST /services/:id/favorite (duplicate) [${dupFavS.status}] -> Idempotent handling`);
  if (dupFavS.status !== 200) throw new Error('Duplicate service favorite failed');

  // Service 9: DELETE /api/v1/services/:id/favorite
  const unFavS = await request('DELETE', `/services/${service.id}/favorite`, null, userB.token);
  recordMetric('DELETE /services/:id/favorite', unFavS.durationMs);
  console.log(`✓ DELETE /services/:id/favorite [${unFavS.status}] -> isFavorited: ${unFavS.data.isFavorited} (${unFavS.durationMs}ms)`);
  if (unFavS.status !== 200 || unFavS.data.isFavorited !== false) throw new Error('Failed unfavorite service');

  // Service 10: POST /api/v1/services/:id/report - Self report block (400)
  const selfRepS = await request('POST', `/services/${service.id}/report`, { reason: 'spam' }, userA.token);
  console.log(`✓ POST /services/:id/report (owner self-report) [${selfRepS.status}] -> Self-report blocked`);
  if (selfRepS.status !== 400) throw new Error('Self report service did not return 400');

  // Service 11: POST /api/v1/services/:id/report - Valid report & duplicate 409
  const repS = await request('POST', `/services/${service.id}/report`, { reason: 'incorrect_info', details: 'Unclear rates' }, userB.token);
  recordMetric('POST /services/:id/report', repS.durationMs);
  console.log(`✓ POST /services/:id/report (User B) [${repS.status}] -> Reported successfully (${repS.durationMs}ms)`);
  if (repS.status !== 200) throw new Error('Failed report service');

  const dupRepS = await request('POST', `/services/${service.id}/report`, { reason: 'spam' }, userB.token);
  console.log(`✓ POST /services/:id/report (duplicate) [${dupRepS.status}] -> 409 Conflict handled`);
  if (dupRepS.status !== 409) throw new Error('Duplicate service report did not return 409');

  // Business 14: DELETE /api/v1/businesses/:id - 403 Forbidden for non-owner
  const delB403 = await request('DELETE', `/businesses/${business.id}`, null, userB.token);
  console.log(`✓ DELETE /businesses/:id (non-owner) [${delB403.status}] -> 403 Forbidden protection`);
  if (delB403.status !== 403) throw new Error('Non-owner DELETE business did not return 403');

  // Service 12: DELETE /api/v1/services/:id - 403 Forbidden for non-owner
  const delS403 = await request('DELETE', `/services/${service.id}`, null, userB.token);
  console.log(`✓ DELETE /services/:id (non-owner) [${delS403.status}] -> 403 Forbidden protection`);
  if (delS403.status !== 403) throw new Error('Non-owner DELETE service did not return 403');

  // -------------------------------------------------------------
  // STEP 4: SPATIAL POSTGIS VERIFICATION (ST_DWithin, ST_Distance)
  // Distance between Indiranagar (12.9716, 77.6412) and Koramangala (12.9352, 77.6245) is ~4.4 km
  // -------------------------------------------------------------
  console.log('\n=== STEP 4: POSTGIS SPATIAL VERIFICATION (1km, 5km, 10km, 25km, 50km) ===');
  const koramangala = { lat: 12.9352, lng: 77.6245 };
  const radii = [1, 5, 10, 25, 50];

  for (const r of radii) {
    const resB = await request('GET', `/businesses?latitude=${koramangala.lat}&longitude=${koramangala.lng}&radius=${r}`, null, userB.token);
    recordMetric(`Spatial Query ${r}km`, resB.durationMs);
    const hasBusiness = resB.data.items?.some(i => i.id === business.id);
    console.log(`[Radius ${r} km] Found ${resB.data.items?.length ?? 0} businesses. Created business found: ${hasBusiness} (${resB.durationMs}ms)`);
    if (r === 1 && hasBusiness) {
      throw new Error(`Business at ~4.4km should NOT be found within 1km radius!`);
    }
    if (r >= 5 && !hasBusiness) {
      throw new Error(`Business at ~4.4km SHOULD be found within ${r}km radius!`);
    }
  }

  // Verify distance calculation returned from PostGIS ST_Distance
  const resDist = await request('GET', `/businesses?latitude=${koramangala.lat}&longitude=${koramangala.lng}&radius=10`, null, userB.token);
  const matchedItem = resDist.data.items?.find(i => i.id === business.id);
  console.log(`✓ Distance calculation check: PostGIS distance = ${matchedItem.distance} (expected ~4.3 - 4.6 km)`);
  if (matchedItem.distance < 4.0 || matchedItem.distance > 5.0) {
    throw new Error(`Unexpected calculated distance: ${matchedItem.distance}`);
  }

  // Category filtering
  const resCatFilter = await request('GET', `/businesses?latitude=${koramangala.lat}&longitude=${koramangala.lng}&radius=10&category=food_dining`, null, userB.token);
  console.log(`✓ Category filter 'food_dining': ${resCatFilter.data.items?.length} items found`);
  if (!resCatFilter.data.items?.some(i => i.id === business.id)) throw new Error('Category filter failed to find business');

  // Text search
  const resTextSearch = await request('GET', `/businesses?latitude=${koramangala.lat}&longitude=${koramangala.lng}&radius=10&query=Gourmet`, null, userB.token);
  console.log(`✓ Text search 'query=Gourmet': ${resTextSearch.data.items?.length} items found`);
  if (!resTextSearch.data.items?.some(i => i.id === business.id)) throw new Error('Text search failed');

  // Sorting by nearest
  const resSort = await request('GET', `/businesses?latitude=${koramangala.lat}&longitude=${koramangala.lng}&radius=10&sortBy=nearest`, null, userB.token);
  console.log(`✓ Sorting 'sortBy=nearest': ${resSort.data.items?.length} items sorted by distance`);
  if (resSort.status !== 200 || !resSort.data.items?.length) throw new Error('Sorting failed');

  // Pagination
  const resPage = await request('GET', `/businesses?latitude=${koramangala.lat}&longitude=${koramangala.lng}&radius=10&limit=1`, null, userB.token);
  console.log(`✓ Pagination: limit=1, returned ${resPage.data.items?.length} items, nextCursor: ${resPage.data.nextCursor ? 'present' : 'none'}`);
  if (resPage.data.items?.length !== 1) throw new Error('Pagination limit failed');

  // -------------------------------------------------------------
  // STEP 5: OPERATING HOURS EVALUATOR VERIFICATION
  // -------------------------------------------------------------
  console.log('\n=== STEP 5: OPERATING HOURS UTILITY VERIFICATION ===');
  // 1. Open Now test
  const openNowHours = {
    monday: { isClosed: false, intervals: [{ open: '00:00', close: '23:59' }] },
  };
  const mondayMidday = new Date('2026-09-21T06:30:00.000Z'); // 12:00 PM IST
  const statusOpen = evaluateOperatingStatus(openNowHours, 'Asia/Kolkata', mondayMidday);
  console.log(`✓ 1. Open now status: isOpen = ${statusOpen.isOpen}, status = ${statusOpen.status}, text = "${statusOpen.statusText}"`);
  if (!statusOpen.isOpen || statusOpen.status !== 'open') throw new Error('Failed Open Now operating hours test');

  // 2. Closed test
  const closedHours = {
    monday: { isClosed: false, intervals: [{ open: '18:00', close: '22:00' }] },
  };
  const statusClosed = evaluateOperatingStatus(closedHours, 'Asia/Kolkata', mondayMidday); // at 12:00 PM
  console.log(`✓ 2. Closed status: isOpen = ${statusClosed.isOpen}, status = ${statusClosed.status}, text = "${statusClosed.statusText}"`);
  if (statusClosed.isOpen) throw new Error('Failed Closed operating hours test');

  // 3. Opens tomorrow test
  const opensTomorrowHours = {
    monday: { isClosed: true },
    tuesday: { isClosed: false, intervals: [{ open: '09:00', close: '18:00' }] },
  };
  const statusTomorrow = evaluateOperatingStatus(opensTomorrowHours, 'Asia/Kolkata', mondayMidday);
  console.log(`✓ 3. Opens tomorrow status: isOpen = ${statusTomorrow.isOpen}, text = "${statusTomorrow.statusText}"`);
  if (!statusTomorrow.statusText.includes('tomorrow')) throw new Error('Failed Opens tomorrow operating hours test');

  // 4. 24 hours test
  const full24Hours = {
    monday: { isClosed: false, intervals: [{ open: '00:00', close: '24:00' }] },
  };
  const status24h = evaluateOperatingStatus(full24Hours, 'Asia/Kolkata', mondayMidday);
  console.log(`✓ 4. 24 hours status: isOpen = ${status24h.isOpen}`);
  if (!status24h.isOpen) throw new Error('Failed 24 hours operating hours test');

  // 5. Closed days test
  const closedDays = {
    monday: { isClosed: true },
    tuesday: { isClosed: true },
    wednesday: { isClosed: true },
  };
  const statusAllClosed = evaluateOperatingStatus(closedDays, 'Asia/Kolkata', mondayMidday);
  console.log(`✓ 5. Closed days status: isOpen = ${statusAllClosed.isOpen}, status = ${statusAllClosed.status}`);
  if (statusAllClosed.isOpen || statusAllClosed.status !== 'closed') throw new Error('Failed Closed days operating hours test');

  // -------------------------------------------------------------
  // STEP 8: SECURITY & VALIDATION CONSTRAINTS
  // -------------------------------------------------------------
  console.log('\n=== STEP 8: SECURITY & VALIDATION TESTING ===');
  // 1. Invalid coordinates validation
  const badCoords = await request('GET', '/businesses?latitude=999&longitude=888', null, userB.token);
  console.log(`✓ Latitude 999 rejected with [${badCoords.status}]`);
  if (badCoords.status !== 400) throw new Error('Invalid coordinates did not return 400');

  // 2. Invalid radius validation (> 100 max)
  const badRadius = await request('GET', '/businesses?latitude=12.93&longitude=77.62&radius=150', null, userB.token);
  console.log(`✓ Radius 150km (above 100km max limit) rejected with [${badRadius.status}]`);
  if (badRadius.status !== 400) throw new Error('Radius > 100km did not return 400');

  // 3. Sub-minimum radius (< 0.5 min)
  const subMinRadius = await request('GET', '/businesses?latitude=12.93&longitude=77.62&radius=0.1', null, userB.token);
  console.log(`✓ Radius 0.1km (below 0.5km min limit) rejected with [${subMinRadius.status}]`);
  if (subMinRadius.status !== 400) throw new Error('Sub-minimum radius did not return 400');

  // -------------------------------------------------------------
  // STEP 10: REGRESSION CHECK FOR PHASES 0-6
  // -------------------------------------------------------------
  console.log('\n=== STEP 10: REGRESSION CHECK FOR PHASES 0-6 ===');
  // Phase 2: User profile & Auth
  const profileRes = await request('GET', '/auth/me', null, userB.token);
  recordMetric('GET /auth/me', profileRes.durationMs);
  console.log(`✓ Phase 2 Profile: [${profileRes.status}] User: ${profileRes.data.displayName} (${profileRes.durationMs}ms)`);
  if (profileRes.status !== 200) throw new Error('Phase 2 regression');

  // Phase 3: Feed
  const feedRes = await request('GET', '/feed/posts', null, userB.token);
  recordMetric('GET /feed/posts', feedRes.durationMs);
  console.log(`✓ Phase 3 Feed: [${feedRes.status}] Items: ${feedRes.data.items?.length ?? 0} (${feedRes.durationMs}ms)`);
  if (feedRes.status !== 200) throw new Error('Phase 3 regression');

  // Phase 4: Nearby
  const nearbyRes = await request('GET', `/nearby/posts?latitude=12.9352&longitude=77.6245&radius=10`, null, userB.token);
  recordMetric('GET /nearby/posts', nearbyRes.durationMs);
  console.log(`✓ Phase 4 Nearby: [${nearbyRes.status}] Items: ${nearbyRes.data.items?.length ?? 0} (${nearbyRes.durationMs}ms)`);
  if (nearbyRes.status !== 200) throw new Error('Phase 4 regression');

  // Phase 5: Communities
  const commRes = await request('GET', '/communities', null, userB.token);
  recordMetric('GET /communities', commRes.durationMs);
  console.log(`✓ Phase 5 Communities: [${commRes.status}] Items: ${commRes.data.items?.length ?? 0} (${commRes.durationMs}ms)`);
  if (commRes.status !== 200) throw new Error('Phase 5 regression');

  // Phase 6: Marketplace
  const mktRes = await request('GET', '/marketplace/listings', null, userB.token);
  recordMetric('GET /marketplace/listings', mktRes.durationMs);
  console.log(`✓ Phase 6 Marketplace: [${mktRes.status}] Items: ${mktRes.data.items?.length ?? 0} (${mktRes.durationMs}ms)`);
  if (mktRes.status !== 200) throw new Error('Phase 6 regression');

  // -------------------------------------------------------------
  // STEP 3 CLEANUP: SOFT DELETE VERIFICATION
  // -------------------------------------------------------------
  console.log('\n=== STEP 3: DELETE ENDPOINTS (SOFT DELETE) ===');
  const delS = await request('DELETE', `/services/${service.id}`, null, userA.token);
  recordMetric('DELETE /services/:id', delS.durationMs);
  console.log(`✓ DELETE /services/:id (owner) [${delS.status}] -> Deleted (${delS.durationMs}ms)`);
  if (delS.status !== 200) throw new Error('Owner delete service failed');

  const delB = await request('DELETE', `/businesses/${business.id}`, null, userA.token);
  recordMetric('DELETE /businesses/:id', delB.durationMs);
  console.log(`✓ DELETE /businesses/:id (owner) [${delB.status}] -> Deleted (${delB.durationMs}ms)`);
  if (delB.status !== 200) throw new Error('Owner delete business failed');

  // -------------------------------------------------------------
  // STEP 11: PERFORMANCE REPORT
  // -------------------------------------------------------------
  console.log('\n=== STEP 11: PERFORMANCE METRICS ===');
  const totalMs = performanceMetrics.reduce((sum, m) => sum + m.durationMs, 0);
  const avgMs = (totalMs / performanceMetrics.length).toFixed(2);
  const maxMs = Math.max(...performanceMetrics.map(m => m.durationMs));
  const minMs = Math.min(...performanceMetrics.map(m => m.durationMs));
  console.log(`Total Operations Measured: ${performanceMetrics.length}`);
  console.log(`Average Response Time: ${avgMs} ms`);
  console.log(`Min Latency: ${minMs} ms | Max Latency: ${maxMs} ms`);
  console.log('\nLatency Breakdown:');
  for (const m of performanceMetrics) {
    console.log(`  - ${m.name.padEnd(35)}: ${m.durationMs} ms`);
  }

  console.log('\n================================================================');
  console.log('   ALL PHASE 7 RUNTIME CHECKS SUCCESSFULLY VERIFIED & PASSED!   ');
  console.log('================================================================\n');
}

main().catch((err) => {
  console.error('\n❌ [Verification Failed]:', err);
  process.exit(1);
});

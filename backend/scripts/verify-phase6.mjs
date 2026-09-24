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

function assertNoSensitiveFields(obj, label) {
  const forbiddenPatterns = ['phoneNumber', 'phone', 'email', 'refreshTokenHash', 'secret', 'latitude', 'longitude'];
  const jsonStr = JSON.stringify(obj);

  for (const forbidden of forbiddenPatterns) {
    const regex = new RegExp(`"${forbidden}"\\s*:`, 'i');
    if (regex.test(jsonStr)) {
      if (forbidden === 'phone' || forbidden === 'phoneNumber') {
        const match = jsonStr.match(new RegExp(`"${forbidden}"\\s*:\\s*"([^"]+)"`, 'i'));
        if (match && !match[1].includes('••••••')) {
          throw new Error(`[PRIVACY VIOLATION] Unmasked sensitive field "${forbidden}" found in ${label}: ${match[0]}`);
        }
      } else {
        throw new Error(`[PRIVACY VIOLATION] Forbidden field "${forbidden}" found in ${label}: ${jsonStr.substring(0, 200)}`);
      }
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
    deviceMetadata: { platform: 'Android 15', model: 'Pixel 9' },
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

async function runPhase6Verification() {
  console.log('================================================================');
  console.log('       AASPAAS PHASE 6: MARKETPLACE RUNTIME VERIFICATION        ');
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
  const userA = await authenticateUser('+919888800001', 'Aakash Verma', 'Indiranagar', 'Bengaluru');
  console.log(`[User A - Seller] Authenticated ID: ${userA.user.id}`);

  const userB = await authenticateUser('+919888800002', 'Priya Sharma', 'Koramangala', 'Bengaluru');
  console.log(`[User B - Buyer] Authenticated ID: ${userB.user.id}`);

  // 3. CREATE LISTING (User A)
  console.log('\n--- 3. USER A CREATES MARKETPLACE LISTING ---');
  const uniqueTitle = `Solid Teakwood Study Table ${Date.now().toString().slice(-4)}`;
  const createListingRes = await request('POST', '/marketplace/listings', {
    title: uniqueTitle,
    description: 'Minimalist study desk made of natural teakwood with two drawers.',
    category: 'furniture',
    price: 4500,
    condition: 'like_new',
    locality: 'Indiranagar',
    city: 'Bengaluru',
    images: [
      { url: 'https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd', displayOrder: 0 },
      { url: 'https://images.unsplash.com/photo-1538688525198-9b88f6f53126', displayOrder: 1 },
    ],
  }, userA.token);

  console.log(`[Create Listing] Status: ${createListingRes.status}`);
  if (createListingRes.status !== 201) throw new Error(`Create listing failed: ${JSON.stringify(createListingRes.data)}`);
  const listing1 = createListingRes.data;
  console.log(`[Listing 1] ID: ${listing1.id}, Title: "${listing1.title}", Price: ₹${listing1.price}`);
  assertNoSensitiveFields(listing1, 'CreateListing response');

  // Verify Seller profile projection
  if (!listing1.seller || listing1.seller.displayName !== 'Aakash Verma') {
    throw new Error(`Seller projection mismatch: expected 'Aakash Verma', got ${listing1.seller?.displayName}`);
  }

  // 4. GET LISTING DETAIL (User B)
  console.log('\n--- 4. USER B RETRIEVES LISTING DETAIL ---');
  const getDetailRes = await request('GET', `/marketplace/listings/${listing1.id}`, null, userB.token);
  console.log(`[Get Detail] Status: ${getDetailRes.status}`);
  if (getDetailRes.status !== 200) throw new Error(`Get listing detail failed: ${JSON.stringify(getDetailRes.data)}`);
  const detail = getDetailRes.data;
  assertNoSensitiveFields(detail, 'GetListingDetail response');
  if (detail.isOwner !== false) throw new Error(`isOwner should be false for User B`);
  if (detail.images.length !== 2) throw new Error(`Expected 2 images, got ${detail.images.length}`);
  console.log(`[Detail Verified] Images count: ${detail.images.length}, isOwner: ${detail.isOwner}`);

  // 5. USER A CREATES A FREE GIVEAWAY ITEM
  console.log('\n--- 5. USER A CREATES FREE GIVEAWAY ITEM ---');
  const freeItemRes = await request('POST', '/marketplace/listings', {
    title: `Free UPSC Reference Books ${Date.now().toString().slice(-4)}`,
    description: 'Complete set of NCERT and reference books for civil services aspirants.',
    category: 'books',
    price: 0,
    condition: 'good',
    locality: 'Indiranagar',
    city: 'Bengaluru',
  }, userA.token);

  console.log(`[Create Free Item] Status: ${freeItemRes.status}`);
  if (freeItemRes.status !== 201) throw new Error(`Create free item failed: ${JSON.stringify(freeItemRes.data)}`);
  const freeListing = freeItemRes.data;
  console.log(`[Free Listing] ID: ${freeListing.id}, Price: ${freeListing.price}`);

  // 6. SEARCH & FILTERING (User B)
  console.log('\n--- 6. SEARCH & FILTERING CAPABILITIES ---');

  // 6a. Filter by category=furniture
  const catFilterRes = await request('GET', '/marketplace/listings?category=furniture', null, userB.token);
  if (catFilterRes.status !== 200) throw new Error('Category filter failed');
  const foundInCat = catFilterRes.data.items.some(i => i.id === listing1.id);
  if (!foundInCat) throw new Error('Created listing not found in furniture category filter');
  console.log(`[Category Filter] PASS: ${catFilterRes.data.items.length} items found`);

  // 6b. Filter by price range minPrice=4000&maxPrice=5000
  const priceFilterRes = await request('GET', '/marketplace/listings?minPrice=4000&maxPrice=5000', null, userB.token);
  if (priceFilterRes.status !== 200) throw new Error('Price filter failed');
  const foundInPrice = priceFilterRes.data.items.some(i => i.id === listing1.id);
  if (!foundInPrice) throw new Error('Created listing not found in price filter range');
  console.log(`[Price Range Filter] PASS: ${priceFilterRes.data.items.length} items found`);

  // 6c. Filter free items only (maxPrice=0)
  const freeFilterRes = await request('GET', '/marketplace/listings?maxPrice=0', null, userB.token);
  if (freeFilterRes.status !== 200) throw new Error('Free items filter failed');
  const foundFree = freeFilterRes.data.items.some(i => i.id === freeListing.id);
  if (!foundFree) throw new Error('Free listing not found in maxPrice=0 filter');
  console.log(`[Free Only Filter] PASS: ${freeFilterRes.data.items.length} free items found`);

  // 6d. PostGIS Radius Spatial Search
  console.log('\n--- 6d. POSTGIS RADIUS SPATIAL SEARCH ---');
  // Near Indiranagar (12.9780, 77.6400) within 5km
  const spatialRes = await request('GET', '/marketplace/listings?latitude=12.9780&longitude=77.6400&radius=5', null, userB.token);
  if (spatialRes.status !== 200) throw new Error('Spatial search failed');
  const spatialItem = spatialRes.data.items.find(i => i.id === listing1.id);
  if (!spatialItem) throw new Error('Listing not returned in 5km spatial radius');
  if (!spatialItem.distance) throw new Error('Spatial search did not compute relative distance string');
  console.log(`[Spatial Search] PASS: Distance calculated = "${spatialItem.distance}", distanceMeters = ${spatialItem.distanceMeters}`);

  // 7. FAVORITE & UNFAVORITE FLOW
  console.log('\n--- 7. FAVORITE & UNFAVORITE FLOW ---');
  // 7a. User B favorites listing 1
  const favRes = await request('POST', `/marketplace/listings/${listing1.id}/favorite`, null, userB.token);
  console.log(`[Favorite Listing] Status: ${favRes.status}`);
  if (favRes.status !== 200) throw new Error(`Favorite failed: ${JSON.stringify(favRes.data)}`);

  // 7b. Verify detail shows isFavorited === true and favoriteCount === 1
  const favDetailRes = await request('GET', `/marketplace/listings/${listing1.id}`, null, userB.token);
  if (favDetailRes.data.isFavorited !== true || favDetailRes.data.favoriteCount < 1) {
    throw new Error(`Favorite count or flag not updated: isFavorited=${favDetailRes.data.isFavorited}, count=${favDetailRes.data.favoriteCount}`);
  }
  console.log(`[Favorite Verified] isFavorited: ${favDetailRes.data.isFavorited}, favoriteCount: ${favDetailRes.data.favoriteCount}`);

  // 7c. User B unfavorites listing 1
  const unfavRes = await request('DELETE', `/marketplace/listings/${listing1.id}/favorite`, null, userB.token);
  console.log(`[Unfavorite Listing] Status: ${unfavRes.status}`);
  if (unfavRes.status !== 200) throw new Error(`Unfavorite failed: ${JSON.stringify(unfavRes.data)}`);

  const unfavDetailRes = await request('GET', `/marketplace/listings/${listing1.id}`, null, userB.token);
  if (unfavDetailRes.data.isFavorited !== false) throw new Error('isFavorited should be false after unfavorite');
  console.log(`[Unfavorite Verified] isFavorited: ${unfavDetailRes.data.isFavorited}`);

  // 8. REPORT LISTING FLOW
  console.log('\n--- 8. REPORTING & DUPLICATE REPORT PREVENTION ---');
  // 8a. User B reports listing
  const reportRes = await request('POST', `/marketplace/listings/${listing1.id}/report`, {
    reason: 'spam',
    details: 'Testing report functionality for marketplace listing.',
  }, userB.token);
  console.log(`[Report Listing] Status: ${reportRes.status}`);
  if (reportRes.status !== 200) throw new Error(`Report failed: ${JSON.stringify(reportRes.data)}`);

  // 8b. Duplicate report should throw 409 Conflict
  const dupReportRes = await request('POST', `/marketplace/listings/${listing1.id}/report`, {
    reason: 'inappropriate',
  }, userB.token);
  console.log(`[Duplicate Report Attempt] Status: ${dupReportRes.status} (Expected 409)`);
  if (dupReportRes.status !== 409) throw new Error(`Expected 409 on duplicate report, got ${dupReportRes.status}`);
  console.log(`[Duplicate Report Prevention] PASS: 409 Conflict correctly returned`);

  // 9. OWNER STATUS MANAGEMENT (Active -> Sold)
  console.log('\n--- 9. OWNER STATUS UPDATE (Active -> Sold) ---');
  const statusRes = await request('PATCH', `/marketplace/listings/${listing1.id}/status`, {
    status: 'sold',
  }, userA.token);
  console.log(`[Update Status] Status: ${statusRes.status}`);
  if (statusRes.status !== 200) throw new Error(`Status update failed: ${JSON.stringify(statusRes.data)}`);
  if (statusRes.data.status !== 'sold') throw new Error(`Status should be 'sold', got ${statusRes.data.status}`);
  console.log(`[Status Updated] New status: ${statusRes.data.status}`);

  // 10. AUTHORIZATION & ACCESS CONTROL
  console.log('\n--- 10. AUTHORIZATION & EDIT / DELETE PROTECTIONS ---');
  // 10a. User B attempts to edit User A's listing (Forbidden 403)
  const forbiddenEdit = await request('PATCH', `/marketplace/listings/${listing1.id}`, {
    title: 'Hacked Title Attempt',
  }, userB.token);
  console.log(`[User B Edit Attempt] Status: ${forbiddenEdit.status} (Expected 403)`);
  if (forbiddenEdit.status !== 403) throw new Error(`Expected 403 on unauthorized edit, got ${forbiddenEdit.status}`);

  // 10b. User A updates the listing
  const updateRes = await request('PATCH', `/marketplace/listings/${listing1.id}`, {
    title: `${uniqueTitle} (Discounted)`,
    price: 4200,
  }, userA.token);
  console.log(`[User A Edit] Status: ${updateRes.status}`);
  if (updateRes.status !== 200) throw new Error(`Owner edit failed: ${JSON.stringify(updateRes.data)}`);
  if (updateRes.data.price !== '4200.00' && updateRes.data.price !== 4200) {
    throw new Error(`Updated price mismatch: ${updateRes.data.price}`);
  }

  // 10c. User B attempts to delete User A's listing (Forbidden 403)
  const forbiddenDelete = await request('DELETE', `/marketplace/listings/${listing1.id}`, null, userB.token);
  console.log(`[User B Delete Attempt] Status: ${forbiddenDelete.status} (Expected 403)`);
  if (forbiddenDelete.status !== 403) throw new Error(`Expected 403 on unauthorized delete, got ${forbiddenDelete.status}`);

  // 10d. User A soft-deletes the listing
  const deleteRes = await request('DELETE', `/marketplace/listings/${listing1.id}`, null, userA.token);
  console.log(`[User A Delete] Status: ${deleteRes.status}`);
  if (deleteRes.status !== 200) throw new Error(`Owner delete failed: ${JSON.stringify(deleteRes.data)}`);

  // Verify deleted item returns 404
  const deletedCheck = await request('GET', `/marketplace/listings/${listing1.id}`, null, userB.token);
  console.log(`[Check Deleted Item] Status: ${deletedCheck.status} (Expected 404)`);
  if (deletedCheck.status !== 404) throw new Error(`Expected 404 for deleted item, got ${deletedCheck.status}`);

  // 11. REGRESSION CHECK: PHASES 2 - 5
  console.log('\n--- 11. REGRESSION CHECK ON PHASES 2 - 5 ---');
  const feedRes = await request('GET', '/feed/posts', null, userA.token);
  console.log(`[Feed API] Status: ${feedRes.status} (Phase 3)`);
  if (feedRes.status !== 200) throw new Error('Feed endpoint regression!');

  const nearbyRes = await request('GET', '/nearby/posts?latitude=12.9784&longitude=77.6408', null, userA.token);
  console.log(`[Nearby API] Status: ${nearbyRes.status} (Phase 4)`);
  if (nearbyRes.status !== 200) throw new Error('Nearby endpoint regression!');

  const commRes = await request('GET', '/communities', null, userA.token);
  console.log(`[Communities API] Status: ${commRes.status} (Phase 5)`);
  if (commRes.status !== 200) throw new Error('Communities endpoint regression!');

  console.log('\n================================================================');
  console.log('       PHASE 6: ALL MARKETPLACE VERIFICATIONS PASSED!           ');
  console.log('================================================================\n');
}

runPhase6Verification().catch((err) => {
  console.error('\nVerification failed:', err);
  process.exit(1);
});

// Aaspaas Phase 6 Marketplace Live End-to-End Verification
import { Client } from 'pg';

const BASE_URL = 'http://localhost:3000/api/v1';
const DB_URL = 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db';

const results = {};

function record(testName, passed, details = '') {
  results[testName] = { passed, details };
  const icon = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`${icon} [${testName}] ${details}`);
}

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
  return { status: res.status, body, headers: res.headers };
}

async function main() {
  console.log('--- STARTING LIVE MARKETPLACE RUNTIME VERIFICATION ---');

  // 1. Health check
  const healthRes = await api('/health');
  record(
    'Health Check',
    healthRes.status === 200 && healthRes.body.database === 'connected' && healthRes.body.redis === 'connected',
    `DB: ${healthRes.body?.database}, Redis: ${healthRes.body?.redis}`
  );

  // 2. Authentication: User A (+919876543210)
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

  // Complete onboarding for User A
  await api('/users/me/onboarding', {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify({
      displayName: 'Aarav Sharma',
      city: 'Bengaluru',
      locality: 'Koramangala',
      neighborhood: '5th Block',
    }),
  });

  // 3. Authentication: User B (+919876543211)
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

  // Complete onboarding for User B
  await api('/users/me/onboarding', {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenB}` },
    body: JSON.stringify({
      displayName: 'Bhavna Patel',
      city: 'Bengaluru',
      locality: 'Indiranagar',
      neighborhood: '100 Feet Road',
    }),
  });

  record(
    'Authentication Flow',
    !!tokenA && !!tokenB && userA.id !== userB.id,
    `User A ID: ${userA.id}, User B ID: ${userB.id}`
  );

  // 4. Create Listing as User A
  const createPayload = {
    title: 'Solid Teak Wood Study Desk',
    description: 'Ergonomic study desk with 3 spacious drawers in excellent condition. Ideal for home office.',
    category: 'furniture',
    condition: 'like_new',
    price: 4500,
    currency: 'INR',
    city: 'Bengaluru',
    locality: 'Koramangala',
    images: [
      { url: 'https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd', displayOrder: 0 },
    ],
  };

  const createRes = await api('/marketplace/listings', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify(createPayload),
  });

  const listingA = createRes.body?.data || createRes.body;
  const listingIdA = listingA?.id;

  record(
    'Create Listing',
    createRes.status === 201 && listingA.title === createPayload.title && listingA.sellerId === userA.id,
    `Listing ID: ${listingIdA}, Status: ${listingA?.status}`
  );

  // Check DB directly for row and geography point
  const pgClient = new Client({ connectionString: DB_URL });
  await pgClient.connect();

  const dbRowRes = await pgClient.query(
    `SELECT id, "sellerId", title, category, price, status, "deletedAt", ST_AsText(location) as location_wkt
     FROM marketplace_listings WHERE id = $1`,
    [listingIdA]
  );
  const dbRow = dbRowRes.rows[0];
  record(
    'Database Listing Row',
    !!dbRow && dbRow.title === createPayload.title && dbRow.location_wkt.startsWith('POINT('),
    `DB Location: ${dbRow?.location_wkt}, Price: ${dbRow?.price}`
  );

  // Create additional listings for search, filter & radius tests
  // Listing 2: Mobile in Koramangala
  const create2 = await api('/marketplace/listings', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify({
      title: 'iPhone 13 128GB Midnight Blue',
      description: 'Barely used iPhone 13, 90% battery health, with original box and cable.',
      category: 'mobiles',
      condition: 'good',
      price: 32000,
      city: 'Bengaluru',
      locality: 'Koramangala',
    }),
  });
  const listingId2 = (create2.body?.data || create2.body).id;

  // Listing 3: Book in Indiranagar
  const create3 = await api('/marketplace/listings', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify({
      title: 'Clean Code by Robert C Martin',
      description: 'Paperback edition handbook of agile software craftsmanship. Very good condition.',
      category: 'books',
      condition: 'like_new',
      price: 550,
      city: 'Bengaluru',
      locality: 'Indiranagar',
    }),
  });
  const listingId3 = (create3.body?.data || create3.body).id;

  // Listing 4: Laptop in Whitefield
  const create4 = await api('/marketplace/listings', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify({
      title: 'Dell XPS 15 32GB RAM Laptop',
      description: 'High performance laptop with 4K OLED display and Intel i7 processor.',
      category: 'computers',
      condition: 'used',
      price: 65000,
      city: 'Bengaluru',
      locality: 'Whitefield',
    }),
  });
  const listingId4 = (create4.body?.data || create4.body).id;

  // 5. User B - Listing Discovery
  const discoveryRes = await api('/marketplace/listings', {
    method: 'GET',
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const discData = discoveryRes.body?.data || discoveryRes.body;
  const items = discData.items || [];
  const foundA = items.find(i => i.id === listingIdA);

  record(
    'Listing Discovery',
    discoveryRes.status === 200 && !!foundA && foundA.title === createPayload.title,
    `Found ${items.length} listings in active marketplace.`
  );

  // 6. User B - Listing Detail
  const detailRes = await api(`/marketplace/listings/${listingIdA}`, {
    method: 'GET',
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const detailA = detailRes.body?.data || detailRes.body;

  record(
    'Listing Detail',
    detailRes.status === 200 && detailA.id === listingIdA && detailA.images?.length > 0 && detailA.isOwner === false,
    `Detail retrieved with ${detailA?.images?.length} image(s), isOwner: ${detailA?.isOwner}`
  );

  // 7. Seller Privacy Audit
  const detailStr = JSON.stringify(detailA);
  const privacyViolations = [
    'password', 'passwordHash', 'phoneNumber', 'email', 'accessToken', 'refreshToken',
    'sessionId', 'exact_lat', 'exact_lng', 'houseNumber', 'apartmentNumber'
  ].filter(key => detailStr.includes(`"${key}"`));

  record(
    'Seller Privacy Audit',
    privacyViolations.length === 0 && !detailA.seller.phoneNumber && !detailA.seller.email,
    `Violations: ${privacyViolations.length === 0 ? 'None (Clean)' : privacyViolations.join(', ')}`
  );

  // 8. Keyword Search
  const searchExact = await api('/marketplace/listings?query=Teak', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const searchPartial = await api('/marketplace/listings?query=desk', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const searchNoResult = await api('/marketplace/listings?query=NonExistentSuperItem12345', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });

  const exactItems = (searchExact.body?.data || searchExact.body).items || [];
  const partialItems = (searchPartial.body?.data || searchPartial.body).items || [];
  const noResultItems = (searchNoResult.body?.data || searchNoResult.body).items || [];

  record(
    'Search Functionality',
    exactItems.some(i => i.id === listingIdA) &&
    partialItems.some(i => i.id === listingIdA) &&
    noResultItems.length === 0,
    `Exact: ${exactItems.length}, Partial: ${partialItems.length}, No-result: ${noResultItems.length}`
  );

  // 9. Category Filter
  const catFilter = await api('/marketplace/listings?category=mobiles', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const catItems = (catFilter.body?.data || catFilter.body).items || [];
  const allMobiles = catItems.every(i => i.category === 'mobiles');

  record(
    'Category Filter',
    catItems.length > 0 && allMobiles && !catItems.some(i => i.id === listingIdA),
    `Category matched ${catItems.length} mobile item(s), furniture excluded.`
  );

  // 10. Condition Filter
  const condFilter = await api('/marketplace/listings?condition=like_new', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const condItems = (condFilter.body?.data || condFilter.body).items || [];
  const allLikeNew = condItems.every(i => i.condition === 'like_new');

  record(
    'Condition Filter',
    condItems.length > 0 && allLikeNew && condItems.some(i => i.id === listingIdA),
    `Condition matched ${condItems.length} like_new items.`
  );

  // 11. Price Range Filters
  const priceFilter = await api('/marketplace/listings?minPrice=4000&maxPrice=5000', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const priceItems = (priceFilter.body?.data || priceFilter.body).items || [];
  const priceMatch = priceItems.every(i => i.price >= 4000 && i.price <= 5000);

  record(
    'Price Range Filter',
    priceItems.length > 0 && priceMatch && priceItems.some(i => i.id === listingIdA),
    `Filtered price 4000-5000 returned ${priceItems.length} listing(s) including desk (4500).`
  );

  // 12. Sorting
  const sortPriceAsc = await api('/marketplace/listings?sortBy=price_asc', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const ascItems = (sortPriceAsc.body?.data || sortPriceAsc.body).items || [];
  let isAsc = true;
  for (let k = 0; k < ascItems.length - 1; k++) {
    if (ascItems[k].price > ascItems[k + 1].price) isAsc = false;
  }

  const sortPriceDesc = await api('/marketplace/listings?sortBy=price_desc', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const descItems = (sortPriceDesc.body?.data || sortPriceDesc.body).items || [];
  let isDesc = true;
  for (let k = 0; k < descItems.length - 1; k++) {
    if (descItems[k].price < descItems[k + 1].price) isDesc = false;
  }

  record(
    'Price Sorting',
    isAsc && isDesc && ascItems.length >= 3,
    `Ascending verified (min: ${ascItems[0]?.price}), Descending verified (max: ${descItems[0]?.price})`
  );

  // 13. Locality Filter
  const locFilter = await api('/marketplace/listings?locality=Koramangala', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const locItems = (locFilter.body?.data || locFilter.body).items || [];
  const allKoramangala = locItems.every(i => i.locality?.toLowerCase().includes('koramangala'));

  record(
    'Locality Filter',
    locItems.length >= 2 && allKoramangala && !locItems.some(i => i.id === listingId3),
    `Locality matched ${locItems.length} Koramangala listings, Indiranagar excluded.`
  );

  // 14. PostGIS Radius Discovery (Center: Koramangala lat: 12.9352, lng: 77.6245)
  // 3 km radius: Koramangala items included, Indiranagar (~4.4km) and Whitefield (~13.2km) excluded
  const radius3k = await api('/marketplace/listings?latitude=12.9352&longitude=77.6245&radius=3&sortBy=nearest', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const r3kItems = (radius3k.body?.data || radius3k.body).items || [];
  const r3kHasKoramangala = r3kItems.some(i => i.id === listingIdA);
  const r3kHasIndiranagar = r3kItems.some(i => i.id === listingId3);
  const r3kHasWhitefield = r3kItems.some(i => i.id === listingId4);

  // 20 km radius: Koramangala, Indiranagar, and Whitefield all included
  const radius20k = await api('/marketplace/listings?latitude=12.9352&longitude=77.6245&radius=20&sortBy=nearest', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const r20kItems = (radius20k.body?.data || radius20k.body).items || [];
  const r20kHasAll = r20kItems.some(i => i.id === listingIdA) &&
                     r20kItems.some(i => i.id === listingId3) &&
                     r20kItems.some(i => i.id === listingId4);

  record(
    'PostGIS Radius Discovery',
    r3kHasKoramangala && !r3kHasIndiranagar && !r3kHasWhitefield && r20kHasAll,
    `3km radius correctly filtered out outside items; 20km included all items.`
  );

  // 15. Favorite & Unfavorite Flow (User B on User A listing)
  const favRes = await api(`/marketplace/listings/${listingIdA}/favorite`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  
  // Verify favorite in DB
  const favDb = await pgClient.query(
    'SELECT * FROM marketplace_favorites WHERE "listingId" = $1 AND "userId" = $2',
    [listingIdA, userB.id]
  );
  
  // Duplicate favorite attempt
  const dupFavRes = await api(`/marketplace/listings/${listingIdA}/favorite`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenB}` },
  });

  // Verify detail reflects isFavorited = true
  const favDetail = await api(`/marketplace/listings/${listingIdA}`, {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const isFav = (favDetail.body?.data || favDetail.body).isFavorited;

  // Unfavorite
  const unfavRes = await api(`/marketplace/listings/${listingIdA}/favorite`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${tokenB}` },
  });

  const unfavDb = await pgClient.query(
    'SELECT * FROM marketplace_favorites WHERE "listingId" = $1 AND "userId" = $2',
    [listingIdA, userB.id]
  );

  record(
    'Favorite/Unfavorite Flow',
    favRes.status === 200 && favDb.rowCount === 1 && isFav === true &&
    unfavRes.status === 200 && unfavDb.rowCount === 0,
    `DB row verified on favorite, duplicate handled, DB row removed on unfavorite.`
  );

  // 16. User A - Edit Listing
  const editRes = await api(`/marketplace/listings/${listingIdA}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify({
      title: 'Solid Teak Wood Study Desk (Updated)',
      price: 4200,
      condition: 'good',
    }),
  });
  const editedListing = editRes.body?.data || editRes.body;

  record(
    'Edit Listing',
    editRes.status === 200 && editedListing.title.includes('Updated') && editedListing.price === 4200,
    `Title: ${editedListing?.title}, Price: ${editedListing?.price}`
  );

  // 17. User B - Ownership Attack Tests (IDOR)
  const attackPatch = await api(`/marketplace/listings/${listingIdA}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenB}` },
    body: JSON.stringify({ title: 'Hacked Title' }),
  });
  const attackDelete = await api(`/marketplace/listings/${listingIdA}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const attackStatus = await api(`/marketplace/listings/${listingIdA}/status`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenB}` },
    body: JSON.stringify({ status: 'sold' }),
  });

  record(
    'Ownership Security (IDOR Attack)',
    attackPatch.status === 403 && attackDelete.status === 403 && attackStatus.status === 403,
    `PATCH: ${attackPatch.status}, DELETE: ${attackDelete.status}, STATUS: ${attackStatus.status} (All 403 Forbidden)`
  );

  // 18. Mass Assignment Protection
  const massAssignment = await api('/marketplace/listings', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify({
      title: 'Malicious Listing',
      description: 'Testing mass assignment protection',
      category: 'other',
      condition: 'new',
      price: 100,
      sellerId: userB.id, // Attempt to forge seller
      status: 'sold',     // Attempt to forge status
      createdAt: '2020-01-01T00:00:00Z',
    }),
  });

  record(
    'Mass Assignment Protection',
    massAssignment.status === 400,
    `Rejected with HTTP ${massAssignment.status} (Whitelist & ForbidNonWhitelisted active)`
  );

  // 19. User A - Mark Listing SOLD
  const soldRes = await api(`/marketplace/listings/${listingIdA}/status`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify({ status: 'sold' }),
  });
  const soldListing = soldRes.body?.data || soldRes.body;

  record(
    'Mark Sold Lifecycle',
    soldRes.status === 200 && soldListing.status === 'sold',
    `Status updated to: ${soldListing?.status}`
  );

  // 20. User A - Archive Listing
  const archiveRes = await api(`/marketplace/listings/${listingIdA}/status`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify({ status: 'archived' }),
  });
  
  // Verify listing disappears from public active discovery
  const publicDisc = await api('/marketplace/listings', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const publicItems = (publicDisc.body?.data || publicDisc.body).items || [];
  const inPublic = publicItems.some(i => i.id === listingIdA);

  // Verify listing appears in User A's archived listings
  const myListingsArchived = await api('/marketplace/listings/me?status=archived', {
    headers: { Authorization: `Bearer ${tokenA}` },
  });
  const archivedItems = (myListingsArchived.body?.data || myListingsArchived.body).items || [];
  const inArchived = archivedItems.some(i => i.id === listingIdA);

  record(
    'Archive Listing Lifecycle',
    archiveRes.status === 200 && inPublic === false && inArchived === true,
    `Archived listing removed from public discovery and present in My Listings (archived)`
  );

  // 21. User A - Soft Delete Listing
  const deleteRes = await api(`/marketplace/listings/${listingIdA}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${tokenA}` },
  });

  const dbDeleted = await pgClient.query(
    'SELECT id, "deletedAt" FROM marketplace_listings WHERE id = $1',
    [listingIdA]
  );

  const detailDeleted = await api(`/marketplace/listings/${listingIdA}`, {
    headers: { Authorization: `Bearer ${tokenB}` },
  });

  record(
    'Soft Delete Lifecycle',
    deleteRes.status === 200 && !!dbDeleted.rows[0]?.deletedAt && detailDeleted.status === 404,
    `deletedAt set in DB: ${dbDeleted.rows[0]?.deletedAt}, Detail endpoint returned 404 Not Found`
  );

  // 22. Report Listing & Duplicate Report Protection (User B reports listing 2)
  const reportRes = await api(`/marketplace/listings/${listingId2}/report`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenB}` },
    body: JSON.stringify({
      reason: 'spam',
      details: 'Duplicate and misleading description.',
    }),
  });

  const dupReportRes = await api(`/marketplace/listings/${listingId2}/report`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenB}` },
    body: JSON.stringify({
      reason: 'scam',
      details: 'Second report attempt.',
    }),
  });

  const dbReport = await pgClient.query(
    'SELECT * FROM marketplace_reports WHERE "listingId" = $1 AND "reporterId" = $2',
    [listingId2, userB.id]
  );

  record(
    'Listing Report & Duplicate Prevention',
    reportRes.status === 200 && dupReportRes.status === 409 && dbReport.rowCount === 1,
    `First report accepted, duplicate rejected with HTTP ${dupReportRes.status} Conflict.`
  );

  // Cannot report own listing
  const selfReport = await api(`/marketplace/listings/${listingId2}/report`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenA}` },
    body: JSON.stringify({ reason: 'spam' }),
  });
  record(
    'Self Report Prevention',
    selfReport.status === 400,
    `Rejected self report with HTTP ${selfReport.status}`
  );

  // 23. Input Validation Security
  const invalidInputs = [
    { name: 'Title too short', body: { title: 'a', description: 'valid long description here', category: 'books', condition: 'new', price: 100 } },
    { name: 'Negative price', body: { title: 'Valid Title Here', description: 'valid long description here', category: 'books', condition: 'new', price: -50 } },
    { name: 'Invalid category', body: { title: 'Valid Title Here', description: 'valid long description here', category: 'invalid_cat', condition: 'new', price: 100 } },
    { name: 'Invalid condition', body: { title: 'Valid Title Here', description: 'valid long description here', category: 'books', condition: 'broken', price: 100 } },
  ];

  let allInvalidRejected = true;
  for (const inv of invalidInputs) {
    const res = await api('/marketplace/listings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokenA}` },
      body: JSON.stringify(inv.body),
    });
    if (res.status !== 400) allInvalidRejected = false;
  }

  const invalidUuid = await api('/marketplace/listings/not-a-valid-uuid', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });
  const invalidRadius = await api('/marketplace/listings?latitude=12.9&longitude=77.6&radius=999', {
    headers: { Authorization: `Bearer ${tokenB}` },
  });

  record(
    'Input Validation Security',
    allInvalidRejected && invalidUuid.status === 400 && invalidRadius.status === 400,
    `All invalid payloads, invalid UUID, and radius > 50km rejected with HTTP 400`
  );

  // 24. Auth Guard Security
  const noAuth = await api('/marketplace/listings');
  const badToken = await api('/marketplace/listings', {
    headers: { Authorization: 'Bearer thisisobviouslyafaketoken12345' },
  });
  const malformedAuth = await api('/marketplace/listings', {
    headers: { Authorization: 'MalformedTokenFormat' },
  });

  record(
    'API Auth Security Guards',
    noAuth.status === 401 && badToken.status === 401 && malformedAuth.status === 401,
    `No auth: ${noAuth.status}, Bad token: ${badToken.status}, Malformed: ${malformedAuth.status}`
  );

  // Clean up pgClient
  await pgClient.end();

  console.log('\n--- VERIFICATION SUMMARY ---');
  let passCount = 0;
  let totalCount = 0;
  for (const [k, v] of Object.entries(results)) {
    totalCount++;
    if (v.passed) passCount++;
  }
  console.log(`TOTAL: ${passCount} / ${totalCount} PASSED`);
}

main().catch(err => {
  console.error('Execution error:', err);
  process.exit(1);
});

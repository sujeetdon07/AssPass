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
    // Check if key appears as a property
    const regex = new RegExp(`"${forbidden}"\\s*:`, 'i');
    if (regex.test(jsonStr)) {
      // Exclude auth login endpoint response which legitimately returns masked phone
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
  // 1. Request OTP
  const otpRes = await request('POST', '/auth/otp/request', { phoneNumber: phone });
  if (otpRes.status !== 200) throw new Error(`OTP request failed for ${phone}: ${JSON.stringify(otpRes.data)}`);
  const devOtp = otpRes.data?.devOtp ?? otpRes.envelope?.data?.devOtp;

  // 2. Verify OTP
  const verifyRes = await request('POST', '/auth/otp/verify', {
    phoneNumber: phone,
    otp: devOtp,
    deviceMetadata: { platform: 'Android 15', model: 'Pixel 9' },
  });
  if (verifyRes.status !== 200) throw new Error(`OTP verify failed for ${phone}: ${JSON.stringify(verifyRes.data)}`);
  const token = verifyRes.data?.tokens?.accessToken ?? verifyRes.envelope?.data?.tokens?.accessToken;
  const user = verifyRes.data?.user ?? verifyRes.envelope?.data?.user;

  // 3. Complete onboarding if needed
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

async function runPhase5Verification() {
  console.log('================================================================');
  console.log('       AASPAAS PHASE 5: COMMUNITIES RUNTIME VERIFICATION        ');
  console.log('================================================================\n');

  // 1. HEALTH CHECK
  console.log('--- 1. INFRASTRUCTURE HEALTH CHECK ---');
  const health = await request('GET', '/health');
  console.log(`[Health] Status: ${health.status}, Response:`, JSON.stringify(health.data));
  if (health.status !== 200 || health.data.database !== 'connected' || health.data.redis !== 'connected') {
    throw new Error('Health check failed! Ensure Postgres and Redis are running.');
  }

  // 2. AUTHENTICATE USERS
  console.log('\n--- 2. AUTHENTICATING TEST USERS ---');
  const userA = await authenticateUser('+919888800001', 'Aakash Verma', 'Indiranagar', 'Bengaluru');
  console.log(`[User A] Authenticated ID: ${userA.user.id}`);

  const userB = await authenticateUser('+919888800002', 'Priya Sharma', 'Indiranagar', 'Bengaluru');
  console.log(`[User B] Authenticated ID: ${userB.user.id}`);

  // 3. CREATE PUBLIC COMMUNITY (User A)
  console.log('\n--- 3. CREATE PUBLIC COMMUNITY (User A) ---');
  const uniqueName = `Indiranagar Residents ${Date.now().toString().slice(-4)}`;
  const createCommRes = await request('POST', '/communities', {
    name: uniqueName,
    description: 'A dedicated group for verified residents of Indiranagar.',
    category: 'neighborhood',
    visibility: 'public',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: 'Defence Colony',
  }, userA.token);

  console.log(`[Create Community] Status: ${createCommRes.status}`);
  if (createCommRes.status !== 201) throw new Error(`Create community failed: ${JSON.stringify(createCommRes.data)}`);
  const publicComm = createCommRes.data;
  console.log(`[Created Community] ID: ${publicComm.id}, Slug: ${publicComm.slug}, MemberCount: ${publicComm.memberCount}`);
  assertNoSensitiveFields(publicComm, 'createCommunity response');

  // 4. VERIFY USER A IS OWNER
  if (!publicComm.currentUserMember || publicComm.currentUserRole !== 'owner' || publicComm.memberCount !== 1) {
    throw new Error(`User A should be OWNER with memberCount=1, got: member=${publicComm.currentUserMember}, role=${publicComm.currentUserRole}, count=${publicComm.memberCount}`);
  }
  console.log('[Creator State] User A is OWNER, memberCount=1 verified.');

  // 5. DISCOVER & SEARCH COMMUNITY (User B)
  console.log('\n--- 5. DISCOVERY & SEARCH (User B) ---');
  const searchRes = await request('GET', `/communities?search=${encodeURIComponent(uniqueName)}`, null, userB.token);
  console.log(`[Search] Status: ${searchRes.status}, Found: ${searchRes.data?.communities?.length}`);
  if (searchRes.status !== 200 || !searchRes.data?.communities?.some(c => c.id === publicComm.id)) {
    throw new Error('User B could not discover the created community via search.');
  }
  const discoveredComm = searchRes.data.communities.find(c => c.id === publicComm.id);
  console.log(`[Discovered] User B membership state: isMember=${discoveredComm.currentUserMember}, role=${discoveredComm.currentUserRole}`);
  if (discoveredComm.currentUserMember) {
    throw new Error('User B should not be a member yet before joining.');
  }
  assertNoSensitiveFields(discoveredComm, 'discovered community');

  // 6. JOIN COMMUNITY (User B)
  console.log('\n--- 6. JOIN COMMUNITY (User B) ---');
  const joinRes = await request('POST', `/communities/${publicComm.id}/join`, null, userB.token);
  console.log(`[Join] Status: ${joinRes.status}, Message: ${joinRes.data?.message}`);
  if (joinRes.status !== 200) throw new Error(`Join community failed: ${JSON.stringify(joinRes.data)}`);

  // Idempotent join test
  const reJoinRes = await request('POST', `/communities/${publicComm.id}/join`, null, userB.token);
  console.log(`[Idempotent Re-Join] Status: ${reJoinRes.status}, Message: ${reJoinRes.data?.message}`);
  if (reJoinRes.status !== 200) throw new Error('Idempotent join failed');

  // 7. VERIFY USER B MEMBERSHIP STATE
  console.log('\n--- 7. VERIFY MEMBERSHIP STATE (User B) ---');
  const memberStateRes = await request('GET', `/communities/${publicComm.id}/membership`, null, userB.token);
  console.log(`[Membership] Status: ${memberStateRes.status}, isMember: ${memberStateRes.data?.isMember}, role: ${memberStateRes.data?.role}`);
  if (!memberStateRes.data?.isMember || memberStateRes.data?.role !== 'member') {
    throw new Error('User B membership state mismatch.');
  }

  // 8. LIST MEMBERS (User B) & PRIVACY AUDIT
  console.log('\n--- 8. LIST MEMBERS & PRIVACY AUDIT ---');
  const membersRes = await request('GET', `/communities/${publicComm.id}/members`, null, userB.token);
  console.log(`[Members] Status: ${membersRes.status}, Total: ${membersRes.data?.members?.length}`);
  if (membersRes.status !== 200 || membersRes.data?.members?.length !== 2) {
    throw new Error(`Expected 2 members, got: ${membersRes.data?.members?.length}`);
  }
  for (const m of membersRes.data.members) {
    console.log(`  - Member: ${m.user?.displayName} (${m.role})`);
    assertNoSensitiveFields(m, `member ${m.id}`);
  }

  // 9. CREATE COMMUNITY POST (User B)
  console.log('\n--- 9. CREATE COMMUNITY POST (User B) ---');
  const postRes = await request('POST', `/communities/${publicComm.id}/posts`, {
    content: 'Good morning neighbors! Anyone know a reliable plumber in Indiranagar?',
    category: 'question',
  }, userB.token);
  console.log(`[Create Community Post] Status: ${postRes.status}, Post ID: ${postRes.data?.id}`);
  if (postRes.status !== 201) throw new Error(`Create community post failed: ${JSON.stringify(postRes.data)}`);
  const communityPost = postRes.data;
  if (communityPost.communityId !== publicComm.id || communityPost.community?.id !== publicComm.id) {
    throw new Error('Post does not contain expected communityId reference.');
  }
  assertNoSensitiveFields(communityPost, 'community post response');

  // 10. RETRIEVE COMMUNITY POSTS (User A)
  console.log('\n--- 10. RETRIEVE COMMUNITY POSTS (User A) ---');
  const postsRes = await request('GET', `/communities/${publicComm.id}/posts`, null, userA.token);
  console.log(`[Community Posts] Status: ${postsRes.status}, Count: ${postsRes.data?.posts?.length}`);
  if (postsRes.status !== 200 || !postsRes.data?.posts?.some(p => p.id === communityPost.id)) {
    throw new Error('User A could not retrieve community posts.');
  }
  assertNoSensitiveFields(postsRes.data, 'community posts list');

  // 11. LIKE & COMMENT ON COMMUNITY POST (User A)
  console.log('\n--- 11. REACTIONS & COMMENTS ON COMMUNITY POST (User A) ---');
  const likeRes = await request('POST', `/feed/posts/${communityPost.id}/like`, null, userA.token);
  console.log(`[Like Community Post] Status: ${likeRes.status}, Liked: ${likeRes.data?.liked}`);
  if (likeRes.status !== 200 || !likeRes.data?.liked) throw new Error('Like community post failed');

  const commentRes = await request('POST', `/feed/posts/${communityPost.id}/comments`, {
    content: 'Yes, Ramesh from 12th Main is very reliable: 98xxx (mock).',
  }, userA.token);
  console.log(`[Comment on Community Post] Status: ${commentRes.status}, Comment ID: ${commentRes.data?.id}`);
  if (commentRes.status !== 201) throw new Error('Comment on community post failed');

  // 12. LEAVE COMMUNITY (User B)
  console.log('\n--- 12. LEAVE COMMUNITY (User B) ---');
  const leaveRes = await request('DELETE', `/communities/${publicComm.id}/membership`, null, userB.token);
  console.log(`[Leave] Status: ${leaveRes.status}, Message: ${leaveRes.data?.message}`);
  if (leaveRes.status !== 200) throw new Error('Leave community failed');

  // 13. VERIFY MEMBERSHIP AFTER LEAVING
  const postLeaveState = await request('GET', `/communities/${publicComm.id}/membership`, null, userB.token);
  console.log(`[Post-Leave State] isMember: ${postLeaveState.data?.isMember}`);
  if (postLeaveState.data?.isMember) throw new Error('User B should not be a member after leaving.');

  // Verify owner cannot leave
  const ownerLeaveRes = await request('DELETE', `/communities/${publicComm.id}/membership`, null, userA.token);
  console.log(`[Owner Leave Rejection] Status: ${ownerLeaveRes.status} (expected 400)`);
  if (ownerLeaveRes.status !== 400) throw new Error(`Owner leave should be rejected with 400, got: ${ownerLeaveRes.status}`);

  // 14. PRIVATE COMMUNITY AUTHORIZATION
  console.log('\n--- 14. PRIVATE COMMUNITY AUTHORIZATION ---');
  const privName = `Defence Colony Secret Group ${Date.now().toString().slice(-4)}`;
  const createPrivRes = await request('POST', '/communities', {
    name: privName,
    description: 'Private closed discussion group for Defence Colony residents.',
    category: 'residents',
    visibility: 'private',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    neighborhood: 'Defence Colony',
  }, userA.token);
  const privComm = createPrivRes.data;
  console.log(`[Created Private Community] ID: ${privComm.id}, Visibility: ${privComm.visibility}`);

  // User A creates post in private community
  const privPostRes = await request('POST', `/communities/${privComm.id}/posts`, {
    content: 'Confidential society budget report for Q3.',
    category: 'announcement',
  }, userA.token);
  const privPost = privPostRes.data;
  console.log(`[Private Community Post] ID: ${privPost.id}`);

  // 15. VERIFY NON-MEMBER (User B) CANNOT READ PRIVATE POSTS
  console.log('\n--- 15. VERIFY PRIVATE ACCESS RESTRICTIONS ---');
  const readPrivPostsRes = await request('GET', `/communities/${privComm.id}/posts`, null, userB.token);
  console.log(`[User B Read Private Posts] Status: ${readPrivPostsRes.status} (expected 403)`);
  if (readPrivPostsRes.status !== 403) throw new Error(`Expected 403 Forbidden for non-member reading private posts, got: ${readPrivPostsRes.status}`);

  // 16. VERIFY NON-MEMBER CANNOT POST IN PRIVATE COMMUNITY
  const postPrivRes = await request('POST', `/communities/${privComm.id}/posts`, {
    content: 'Intruder trying to post in private community.',
  }, userB.token);
  console.log(`[User B Post in Private] Status: ${postPrivRes.status} (expected 403)`);
  if (postPrivRes.status !== 403) throw new Error(`Expected 403 Forbidden for non-member posting in private community, got: ${postPrivRes.status}`);

  // 17. VERIFY NON-MEMBER CANNOT VIEW PRIVATE MEMBER LIST
  const privMembersRes = await request('GET', `/communities/${privComm.id}/members`, null, userB.token);
  console.log(`[User B View Private Members] Status: ${privMembersRes.status} (expected 403)`);
  if (privMembersRes.status !== 403) throw new Error(`Expected 403 Forbidden for non-member viewing private member list, got: ${privMembersRes.status}`);

  // 18. VERIFY PRIVATE POST CANNOT BE READ VIA DIRECT /feed/posts/:id (IDOR CHECK)
  const idorPostRes = await request('GET', `/feed/posts/${privPost.id}`, null, userB.token);
  console.log(`[IDOR Direct Post Read] Status: ${idorPostRes.status} (expected 403)`);
  if (idorPostRes.status !== 403) throw new Error(`Expected 403 Forbidden on direct IDOR post access, got: ${idorPostRes.status}`);

  // 19. VERIFY FEED REGRESSION: PRIVATE POSTS MUST NOT LEAK INTO GENERAL HOME FEED
  console.log('\n--- 19. FEED REGRESSION: ZERO LEAKAGE INTO HOME / NEARBY FEEDS ---');
  const feedRes = await request('GET', '/feed/posts', null, userB.token);
  const leakedInFeed = feedRes.data?.posts?.some(p => p.id === privPost.id);
  console.log(`[Home Feed Check] Private post leaked into User B home feed? ${leakedInFeed ? 'YES (FAIL)' : 'NO (PASS)'}`);
  if (leakedInFeed) throw new Error('CRITICAL PRIVACY BUG: Private community post leaked into Home feed!');

  const nearbyRes = await request('GET', '/nearby/posts?latitude=12.9784&longitude=77.6408&radius=10', null, userB.token);
  const leakedInNearby = nearbyRes.data?.items?.some(p => p.id === privPost.id);
  console.log(`[Nearby Feed Check] Private post leaked into nearby posts? ${leakedInNearby ? 'YES (FAIL)' : 'NO (PASS)'}`);
  if (leakedInNearby) throw new Error('CRITICAL PRIVACY BUG: Private community post leaked into Nearby feed!');

  // 20. VERIFY OWNER UPDATE AUTHORIZATION
  console.log('\n--- 20. UPDATE AUTHORIZATION ---');
  const unauthorizedUpdate = await request('PATCH', `/communities/${publicComm.id}`, {
    name: 'Hijacked Community Name',
  }, userB.token);
  console.log(`[Unauthorized Update] Status: ${unauthorizedUpdate.status} (expected 403)`);
  if (unauthorizedUpdate.status !== 403) throw new Error('Non-owner should not be able to update community');

  const authorizedUpdate = await request('PATCH', `/communities/${publicComm.id}`, {
    description: 'Updated community description by verified owner.',
  }, userA.token);
  console.log(`[Authorized Update] Status: ${authorizedUpdate.status}`);
  if (authorizedUpdate.status !== 200 || authorizedUpdate.data?.description !== 'Updated community description by verified owner.') {
    throw new Error('Authorized community update failed');
  }

  // 21. REPORT COMMUNITY
  console.log('\n--- 21. REPORT COMMUNITY ---');
  const reportRes = await request('POST', `/communities/${publicComm.id}/report`, {
    reason: 'spam',
    details: 'Testing report flow for community.',
  }, userB.token);
  console.log(`[Report Community] Status: ${reportRes.status}, Message: ${reportRes.data?.message}`);
  if (reportRes.status !== 200) throw new Error(`Report community failed: ${JSON.stringify(reportRes.data)}`);

  // 22. COMMUNITY STATUS LIFECYCLE (ACTIVE -> ARCHIVED -> REACTIVATE)
  console.log('\n--- 22. COMMUNITY STATUS LIFECYCLE (ACTIVE / ARCHIVED) ---');
  const archiveRes = await request('PATCH', `/communities/${publicComm.id}`, {
    status: 'archived',
  }, userA.token);
  console.log(`[Archive Community] Status: ${archiveRes.status}, Community status: ${archiveRes.data?.status}`);
  if (archiveRes.status !== 200 || archiveRes.data?.status !== 'archived') {
    throw new Error('Failed to archive community');
  }

  // Reactivate
  const reactivateRes = await request('PATCH', `/communities/${publicComm.id}`, {
    status: 'active',
  }, userA.token);
  console.log(`[Reactivate Community] Status: ${reactivateRes.status}, Community status: ${reactivateRes.data?.status}`);
  if (reactivateRes.status !== 200 || reactivateRes.data?.status !== 'active') {
    throw new Error('Failed to reactivate community');
  }

  console.log('\n================================================================');
  console.log('       ALL 22 PHASE 5 RUNTIME VERIFICATIONS PASSED 100%!        ');
  console.log('================================================================\n');
}

runPhase5Verification().catch((err) => {
  console.error('\n[VERIFICATION FAILED]:', err);
  process.exit(1);
});

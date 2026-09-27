import pg from 'pg';
const { Client } = pg;

const BASE_URL = 'http://localhost:3000/api/v1';

async function apiRequest(method, endpoint, body = null, token = null) {
  const url = `${BASE_URL}${endpoint}`;
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const contentType = res.headers.get('content-type') || '';
  let data = null;
  if (contentType.includes('application/json')) {
    data = await res.json();
  } else {
    data = await res.text();
  }

  const payload = data && typeof data === 'object' && data.data !== undefined ? data.data : data;
  return { status: res.status, ok: res.ok, data, payload };
}

async function loginUser(phoneNumber) {
  // 1. Request OTP
  const otpRes = await apiRequest('POST', '/auth/otp/request', { phoneNumber });
  if (otpRes.status !== 200 || !otpRes.data?.data?.devOtp) {
    throw new Error(`Failed to get OTP for ${phoneNumber}: ${JSON.stringify(otpRes.data)}`);
  }
  const devOtp = otpRes.data.data.devOtp;

  // 2. Verify OTP
  const verifyRes = await apiRequest('POST', '/auth/otp/verify', {
    phoneNumber,
    otp: devOtp,
  });
  if (verifyRes.status !== 200 || !verifyRes.data?.data?.tokens?.accessToken) {
    throw new Error(`Failed to verify OTP for ${phoneNumber}: ${JSON.stringify(verifyRes.data)}`);
  }

  return {
    userId: verifyRes.data.data.user.id,
    token: verifyRes.data.data.tokens.accessToken,
    refreshToken: verifyRes.data.data.tokens.refreshToken,
  };
}

async function runPhase10E2E() {
  console.log('========================================================================');
  console.log('       AASPAAS PHASE 10 — TRUST & SAFETY LIVE RUNTIME E2E VERIFICATION   ');
  console.log('========================================================================\n');

  const dbClient = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db',
  });
  await dbClient.connect();

  const results = [];
  function assert(name, condition, extra = '') {
    if (condition) {
      console.log(`[PASS] ${name} ${extra ? `(${extra})` : ''}`);
      results.push({ name, pass: true });
    } else {
      console.error(`[FAIL] ${name} ${extra ? `(${extra})` : ''}`);
      results.push({ name, pass: false, error: extra });
      throw new Error(`Verification failed at step: ${name} - ${extra}`);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. HEALTH CHECK
  // ─────────────────────────────────────────────────────────────────────────────
  console.log('--- 1. Infrastructure Health ---');
  const health = await apiRequest('GET', '/health');
  assert('Health Status 200', health.status === 200);
  assert('Database Connected', health.data.database === 'connected');
  assert('Redis Connected', health.data.redis === 'connected');

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. AUTHENTICATION OF TEST USERS
  // ─────────────────────────────────────────────────────────────────────────────
  console.log('\n--- 2. Test Users Authentication ---');
  const userA = await loginUser('+919999910001');
  const userB = await loginUser('+919999910002');
  const userC = await loginUser('+919999910003');
  const moderator = await loginUser('+919999910099');

  // Promote moderator user role in DB
  await dbClient.query(`UPDATE users SET role = 'moderator' WHERE id = $1`, [moderator.userId]);
  // Set display names if null
  await dbClient.query(`UPDATE users SET "displayName" = 'User Alpha' WHERE id = $1`, [userA.userId]);
  await dbClient.query(`UPDATE users SET "displayName" = 'User Beta' WHERE id = $1`, [userB.userId]);
  await dbClient.query(`UPDATE users SET "displayName" = 'User Charlie' WHERE id = $1`, [userC.userId]);
  await dbClient.query(`UPDATE users SET "displayName" = 'Moderator One' WHERE id = $1`, [moderator.userId]);

  assert('User A Authenticated', !!userA.token);
  assert('User B Authenticated', !!userB.token);
  assert('User C Authenticated', !!userC.token);
  assert('Moderator Authenticated & Role Set', !!moderator.token);

  // Check /auth/me
  const meA = await apiRequest('GET', '/auth/me', null, userA.token);
  assert('User A /auth/me works', meA.status === 200 && meA.data.data?.id === userA.userId);

  // Clean any previous blocks between A and B
  await dbClient.query(`DELETE FROM user_blocks WHERE "blockerId" IN ($1, $2) OR "blockedId" IN ($1, $2)`, [userA.userId, userB.userId]);

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. USER BLOCKING TESTS
  // ─────────────────────────────────────────────────────────────────────────────
  console.log('\n--- 3. User Blocking & List Verification ---');

  // Test 3.1: Self-block rejection
  const selfBlock = await apiRequest('POST', '/safety/blocks', { userId: userA.userId }, userA.token);
  assert('Self-block rejected with 400', selfBlock.status === 400);

  // Test 3.2: User A blocks User B
  const blockRes = await apiRequest('POST', '/safety/blocks', { userId: userB.userId }, userA.token);
  assert('User A blocks User B successfully (200)', blockRes.status === 200);

  // Verify in PostgreSQL
  const blockRow = await dbClient.query(
    `SELECT * FROM user_blocks WHERE "blockerId" = $1 AND "blockedId" = $2`,
    [userA.userId, userB.userId]
  );
  assert('UserBlock row exists in PostgreSQL', blockRow.rows.length === 1);

  // Test 3.3: Duplicate block is idempotent
  const dupBlock = await apiRequest('POST', '/safety/blocks', { userId: userB.userId }, userA.token);
  assert('Duplicate block is idempotent (200)', dupBlock.status === 200);

  // Test 3.4: List blocked users
  const listBlocked = await apiRequest('GET', '/safety/blocks', null, userA.token);
  assert('GET /safety/blocks returns 200', listBlocked.status === 200);
  const blockedItems = listBlocked.payload?.items || listBlocked.data?.items || [];
  assert('User B is in blocked list', blockedItems.some(i => i.blockedUser.id === userB.userId));

  // Check NO sensitive data in blocked list projection
  const firstBlocked = blockedItems[0]?.blockedUser;
  assert('No phone number exposed in blocked user list', firstBlocked?.phoneNumber === undefined);
  assert('No email exposed in blocked user list', firstBlocked?.email === undefined);
  assert('No coordinates exposed in blocked user list', firstBlocked?.coordinates === undefined);

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. BLOCK ENFORCEMENT ON MESSAGING
  // ─────────────────────────────────────────────────────────────────────────────
  console.log('\n--- 4. Real Blocking Enforcement on Messaging ---');

  // User B tries to start/get conversation with User A while blocked -> must be 403 Forbidden
  const blockedConv = await apiRequest('POST', '/messaging/conversations', { participantId: userA.userId }, userB.token);
  assert('Blocked user B cannot start conversation with A (403 Forbidden)', blockedConv.status === 403);

  // Test 4.2: Unblock User B
  const unblockRes = await apiRequest('DELETE', `/safety/blocks/${userB.userId}`, null, userA.token);
  assert('User A unblocks User B successfully (200)', unblockRes.status === 200);

  // Verify DB record removed
  const unblockCheck = await dbClient.query(
    `SELECT * FROM user_blocks WHERE "blockerId" = $1 AND "blockedId" = $2`,
    [userA.userId, userB.userId]
  );
  assert('UserBlock row deleted from PostgreSQL', unblockCheck.rows.length === 0);

  // List blocked users -> B must no longer be present
  const listAfterUnblock = await apiRequest('GET', '/safety/blocks', null, userA.token);
  const unblockedItems = listAfterUnblock.payload?.items || listAfterUnblock.data?.items || [];
  assert('User B no longer in blocked list', !unblockedItems.some(i => i.blockedUser.id === userB.userId));

  // Now messaging should succeed
  const allowedConv = await apiRequest('POST', '/messaging/conversations', { participantId: userB.userId }, userA.token);
  assert('Messaging allowed after unblock (200/201)', allowedConv.status === 200 || allowedConv.status === 201);
  const conversationId = allowedConv.payload?.id || allowedConv.data?.id || allowedConv.payload?.conversation?.id;
  assert('Conversation ID retrieved', !!conversationId);

  // Send a test message in the conversation
  const sendMsg = await apiRequest('POST', `/messaging/conversations/${conversationId}/messages`, {
    clientMessageId: `msg_${Date.now()}`,
    content: 'Hello neighbor, this is a test message.',
  }, userA.token);
  assert('User A sends message to B (201)', sendMsg.status === 201);
  const messageId = sendMsg.payload?.id || sendMsg.data?.id;
  assert('Message ID retrieved', !!messageId);

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. TEST CONTENT SEEDING (Post, Comment, Listing, Business, Service)
  // ─────────────────────────────────────────────────────────────────────────────
  console.log('\n--- 5. Content Entities Seeding for Target Validation ---');

  // Clean old test safety reports to keep tests deterministic
  await dbClient.query(`DELETE FROM safety_reports WHERE "reporterId" IN ($1, $2, $3)`, [userA.userId, userB.userId, userC.userId]);

  // Insert a test post
  const postInsert = await dbClient.query(`
    INSERT INTO posts ("authorId", content, category, "countryCode", "city", "locality")
    VALUES ($1, 'Test community post for safety verification', 'general', 'IN', 'Bengaluru', 'Indiranagar')
    RETURNING id;
  `, [userB.userId]);
  const postId = postInsert.rows[0].id;
  assert('Test Post seeded', !!postId);

  // Insert a test comment
  const commentInsert = await dbClient.query(`
    INSERT INTO comments ("postId", "authorId", content)
    VALUES ($1, $2, 'Test comment for safety verification')
    RETURNING id;
  `, [postId, userB.userId]);
  const commentId = commentInsert.rows[0].id;
  assert('Test Comment seeded', !!commentId);

  // Insert test marketplace listing
  const listingInsert = await dbClient.query(`
    INSERT INTO marketplace_listings ("sellerId", title, description, price, category, condition, currency, "countryCode", "city", "locality")
    VALUES ($1, 'Used Bicycle', 'Good condition bicycle', 3500, 'vehicles', 'good', 'INR', 'IN', 'Bengaluru', 'Indiranagar')
    RETURNING id;
  `, [userB.userId]);
  const listingId = listingInsert.rows[0].id;
  assert('Test Marketplace Listing seeded', !!listingId);

  // Insert test business
  const bizInsert = await dbClient.query(`
    INSERT INTO businesses ("ownerId", name, slug, description, category, "countryCode", "city", "locality")
    VALUES ($1, 'Sharma General Store', $2, 'Local grocery and essentials', 'grocery', 'IN', 'Bengaluru', 'Indiranagar')
    RETURNING id;
  `, [userB.userId, `sharma-store-${Date.now()}`]);
  const businessId = bizInsert.rows[0].id;
  assert('Test Business seeded', !!businessId);

  // Insert test service listing
  const svcInsert = await dbClient.query(`
    INSERT INTO service_listings ("ownerId", title, description, category, status, "verificationStatus", "countryCode", "serviceRadiusKm", currency, "city", "locality")
    VALUES ($1, 'Home AC Repair & Cleaning', 'Expert AC service', 'home_repair', 'active', 'verified', 'IN', 10, 'INR', 'Bengaluru', 'Indiranagar')
    RETURNING id;
  `, [userB.userId]);
  const serviceId = svcInsert.rows[0].id;
  assert('Test Service Listing seeded', !!serviceId);

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. REPORTING TESTS ACROSS ALL DOMAINS
  // ─────────────────────────────────────────────────────────────────────────────
  console.log('\n--- 6. Reporting Tests Across All Target Types ---');

  // Test 6.1: User Report
  const userReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'user',
    targetId: userB.userId,
    reason: 'harassment',
    details: 'User repeatedly sends inappropriate messages',
  }, userA.token);
  assert('User report submitted successfully (200)', userReport.status === 200);

  // Verify in PostgreSQL safety_reports table
  const userReportRow = await dbClient.query(`
    SELECT * FROM safety_reports WHERE "reporterId" = $1 AND "targetType" = 'user' AND "targetId" = $2
  `, [userA.userId, userB.userId]);
  assert('User report persisted in safety_reports table', userReportRow.rows.length === 1);
  assert('Status is pending', userReportRow.rows[0].status === 'pending');
  assert('Reason is harassment', userReportRow.rows[0].reason === 'harassment');

  // Test 6.2: User self-report rejection
  const selfReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'user',
    targetId: userA.userId,
    reason: 'spam',
  }, userA.token);
  assert('Self-report rejected with 400', selfReport.status === 400);

  // Test 6.3: Post Report
  const postReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'post',
    targetId: postId,
    reason: 'spam',
    details: 'Spam link in post body',
  }, userA.token);
  assert('Post report submitted successfully (200)', postReport.status === 200);

  // Test 6.4: Post Report Active Deduplication (409 Conflict)
  const dupPostReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'post',
    targetId: postId,
    reason: 'spam',
  }, userA.token);
  assert('Active duplicate post report returns 409 Conflict', dupPostReport.status === 409);

  // Test 6.5: Comment Report
  const commentReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'comment',
    targetId: commentId,
    reason: 'hate_or_abuse',
  }, userA.token);
  assert('Comment report submitted successfully (200)', commentReport.status === 200);

  // Test 6.6: Marketplace Listing Report
  const listingReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'listing',
    targetId: listingId,
    reason: 'scam_or_fraud',
    details: 'Suspicious advance payment request',
  }, userA.token);
  assert('Marketplace listing report submitted successfully (200)', listingReport.status === 200);

  // Test 6.7: Business Report
  const bizReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'business',
    targetId: businessId,
    reason: 'misinformation',
  }, userA.token);
  assert('Business report submitted successfully (200)', bizReport.status === 200);

  // Test 6.8: Service Report
  const svcReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'service',
    targetId: serviceId,
    reason: 'inappropriate_content',
  }, userA.token);
  assert('Service report submitted successfully (200)', svcReport.status === 200);

  // Test 6.9: Conversation Report (Authorized Participant User A)
  const convReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'conversation',
    targetId: conversationId,
    reason: 'threats',
  }, userA.token);
  assert('Authorized conversation report succeeds (200)', convReport.status === 200);

  // Test 6.10: Conversation Report (Unauthorized Non-Participant User C)
  const unauthConvReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'conversation',
    targetId: conversationId,
    reason: 'threats',
  }, userC.token);
  assert('Unauthorized non-participant conversation report rejected (403 Forbidden)', unauthConvReport.status === 403);

  // Test 6.11: Message Report (Authorized Participant User A)
  const msgReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'message',
    targetId: messageId,
    secondaryId: conversationId,
    reason: 'harassment',
  }, userA.token);
  assert('Authorized message report succeeds (200)', msgReport.status === 200);

  // Verify message content was NOT copied into report database
  const msgReportRow = await dbClient.query(`
    SELECT * FROM safety_reports WHERE "targetType" = 'message' AND "targetId" = $1
  `, [messageId]);
  assert('Message report persisted in DB', msgReportRow.rows.length === 1);
  assert('Report does not leak message content into details', msgReportRow.rows[0].details === null);

  // Test 6.12: Message Report (Unauthorized Non-Participant User C)
  const unauthMsgReport = await apiRequest('POST', '/safety/reports', {
    targetType: 'message',
    targetId: messageId,
    reason: 'harassment',
  }, userC.token);
  assert('Unauthorized non-participant message report rejected (403 Forbidden)', unauthMsgReport.status === 403);

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. USER REPORT HISTORY (/reports/me)
  // ─────────────────────────────────────────────────────────────────────────────
  console.log('\n--- 7. Report History Verification ---');

  const historyA = await apiRequest('GET', '/safety/reports/me', null, userA.token);
  assert('User A GET /safety/reports/me returns 200', historyA.status === 200);
  const itemsA = historyA.payload?.items || historyA.data?.items || [];
  assert('User A has report history items', itemsA.length >= 7);

  // Check safe projection: NO reviewerId, NO moderationNotes, NO risk scores
  const sampleItem = itemsA[0];
  assert('Report history item has id, targetType, targetId, reason, status, createdAt',
    !!sampleItem.id && !!sampleItem.targetType && !!sampleItem.targetId && !!sampleItem.reason && !!sampleItem.status && !!sampleItem.createdAt);
  assert('Report history does NOT leak moderationNotes', sampleItem.moderationNotes === undefined);
  assert('Report history does NOT leak reviewerId', sampleItem.reviewerId === undefined && sampleItem.reviewedBy === undefined);

  // User B requests report history -> must NOT see A's reports
  const historyB = await apiRequest('GET', '/safety/reports/me', null, userB.token);
  assert('User B GET /safety/reports/me returns 200', historyB.status === 200);
  const itemsB = historyB.payload?.items || historyB.data?.items || [];
  assert('User B cannot see User A reports', !itemsB.some(i => itemsA.some(a => a.id === i.id)));

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. RATE LIMITING VERIFICATION (10 reports/hour)
  // ─────────────────────────────────────────────────────────────────────────────
  console.log('\n--- 8. Rate Limiting Verification ---');

  // Submit multiple distinct reports from User C until 429
  let rateLimited = false;
  let rateLimitAttempts = 0;
  for (let i = 0; i < 15; i++) {
    rateLimitAttempts++;
    // Generate a fresh test post for each to avoid 409 duplicate
    const p = await dbClient.query(`
      INSERT INTO posts ("authorId", content, category, "countryCode", "city", "locality")
      VALUES ($1, $2, 'general', 'IN', 'Bengaluru', 'Indiranagar')
      RETURNING id;
    `, [userB.userId, `Rate limit test post ${i}`]);
    const pId = p.rows[0].id;

    const rep = await apiRequest('POST', '/safety/reports', {
      targetType: 'post',
      targetId: pId,
      reason: 'spam',
    }, userC.token);

    if (rep.status === 429) {
      rateLimited = true;
      console.log(`[RateLimit] 429 triggered at attempt #${rateLimitAttempts}`);
      break;
    }
  }
  assert('Rate limit (429) triggered after 10 reports', rateLimited);

  // Test that changing targetId does NOT bypass rate limit
  const bypassAttempt = await apiRequest('POST', '/safety/reports', {
    targetType: 'user',
    targetId: userB.userId,
    reason: 'spam',
  }, userC.token);
  assert('Changing target does NOT bypass rate limit (429)', bypassAttempt.status === 429);

  // ─────────────────────────────────────────────────────────────────────────────
  // 9. MODERATION LIFECYCLE & AUDIT TRAIL
  // ─────────────────────────────────────────────────────────────────────────────
  console.log('\n--- 9. Moderation Lifecycle & Audit Trail ---');

  const reportToModerate = userReportRow.rows[0].id;

  // Test 9.1: Ordinary User A attempts to update status -> 403 Forbidden
  const unauthStatusUpdate = await apiRequest('PATCH', `/safety/reports/${reportToModerate}/status`, {
    status: 'actioned',
    reason: 'User should be banned',
  }, userA.token);
  assert('Ordinary USER cannot update report status (403 Forbidden)', unauthStatusUpdate.status === 403);

  // Test 9.2: Ordinary User A attempts to read audit logs -> 403 Forbidden
  const unauthAuditLogs = await apiRequest('GET', '/safety/audit-logs', null, userA.token);
  assert('Ordinary USER cannot read audit logs (403 Forbidden)', unauthAuditLogs.status === 403);

  // Test 9.3: Moderator transitions report: PENDING -> REVIEWING
  const reviewingUpdate = await apiRequest('PATCH', `/safety/reports/${reportToModerate}/status`, {
    status: 'reviewing',
    reason: 'Case opened by moderator',
  }, moderator.token);
  assert('Moderator can transition report to reviewing (200)', reviewingUpdate.status === 200);

  // Test 9.4: Moderator transitions report: REVIEWING -> ACTIONED
  const actionedUpdate = await apiRequest('PATCH', `/safety/reports/${reportToModerate}/status`, {
    status: 'actioned',
    reason: 'Content removed and warning issued',
  }, moderator.token);
  assert('Moderator can transition report to actioned (200)', actionedUpdate.status === 200);

  // Verify status in DB
  const checkStatus = await dbClient.query(`SELECT status FROM safety_reports WHERE id = $1`, [reportToModerate]);
  assert('safety_reports status updated to actioned in PostgreSQL', checkStatus.rows[0].status === 'actioned');

  // Test 9.5: Moderator views audit logs
  const auditLogsRes = await apiRequest('GET', '/safety/audit-logs', null, moderator.token);
  assert('Moderator can query audit logs (200)', auditLogsRes.status === 200);
  const auditItems = auditLogsRes.payload?.items || auditLogsRes.data?.items || [];
  assert('Audit logs contain records', auditItems.length >= 2);

  // Verify audit log row in PostgreSQL
  const dbAudit = await dbClient.query(`
    SELECT * FROM moderation_audit_logs WHERE "reportId" = $1 ORDER BY "createdAt" DESC
  `, [reportToModerate]);
  assert('Audit logs persisted in PostgreSQL moderation_audit_logs table', dbAudit.rows.length >= 2);
  assert('Audit log captures actorId matching moderator', dbAudit.rows[0].actorId === moderator.userId);

  await dbClient.end();

  console.log('\n========================================================================');
  console.log(`       ALL ${results.length} LIVE RUNTIME VERIFICATION CHECKS PASSED!        `);
  console.log('========================================================================');
}

runPhase10E2E().catch(err => {
  console.error('\n[FATAL ERROR IN RUNTIME VERIFICATION]:', err);
  process.exit(1);
});

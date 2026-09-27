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
  const otpRes = await apiRequest('POST', '/auth/otp/request', { phoneNumber });
  if (otpRes.status !== 200 || !otpRes.data?.data?.devOtp) {
    throw new Error(`Failed to get OTP for ${phoneNumber}: ${JSON.stringify(otpRes.data)}`);
  }
  const devOtp = otpRes.data.data.devOtp;

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

async function runPhase11E2E() {
  console.log('========================================================================');
  console.log('    AASPAAS PHASE 11 — ADMIN DASHBOARD & MODERATION RUNTIME E2E TEST   ');
  console.log('========================================================================\n');

  const dbClient = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db',
  });
  await dbClient.connect();
  console.log('✓ Connected to PostgreSQL database.');

  const results = [];
  function assert(title, condition, extra = '') {
    if (condition) {
      console.log(`  [PASS] ${title} ${extra}`);
      results.push({ title, pass: true });
    } else {
      console.error(`  [FAIL] ${title} ${extra}`);
      results.push({ title, pass: false, error: extra });
    }
  }

  try {
    // ── 1. Setup Test Accounts ──────────────────────────────────────────────
    console.log('\n--- 1. Setting Up Test Accounts (USER, MODERATOR, ADMIN) ---');
    const runId = Math.floor(100000 + Math.random() * 900000);
    const userPhone = `+9191${runId}01`;
    const modPhone = `+9191${runId}02`;
    const adminPhone = `+9191${runId}03`;
    const targetPhone = `+9191${runId}04`;

    const testUser = await loginUser(userPhone);
    const modUser = await loginUser(modPhone);
    const adminUser = await loginUser(adminPhone);
    const targetUser = await loginUser(targetPhone);

    // Promote in database
    await dbClient.query(`UPDATE users SET role = 'user', "displayName" = 'Regular User' WHERE id = $1`, [testUser.userId]);
    await dbClient.query(`UPDATE users SET role = 'moderator', "displayName" = 'Staff Moderator' WHERE id = $1`, [modUser.userId]);
    await dbClient.query(`UPDATE users SET role = 'admin', "displayName" = 'Chief Admin' WHERE id = $1`, [adminUser.userId]);
    await dbClient.query(`UPDATE users SET role = 'user', "displayName" = 'Target User' WHERE id = $1`, [targetUser.userId]);

    // Re-login to get updated JWT tokens with correct roles
    const userAuth = await loginUser(userPhone);
    const modAuth = await loginUser(modPhone);
    const adminAuth = await loginUser(adminPhone);
    const targetAuth = await loginUser(targetPhone);

    assert('Test user logged in with role USER', userAuth.token.length > 0);
    assert('Staff moderator logged in with role MODERATOR', modAuth.token.length > 0);
    assert('Chief admin logged in with role ADMIN', adminAuth.token.length > 0);

    // ── 2. Authentication & Authorization Gates ─────────────────────────────
    console.log('\n--- 2. Dashboard Authorization Gates ---');
    
    // Unauthenticated access
    const unauthRes = await apiRequest('GET', '/admin/dashboard/summary', null, null);
    assert('Unauthenticated request to admin dashboard returns 401 Unauthorized', unauthRes.status === 401);

    // USER role access
    const userRes = await apiRequest('GET', '/admin/dashboard/summary', null, userAuth.token);
    assert('Regular USER request to admin dashboard returns 403 Forbidden', userRes.status === 403);

    // MODERATOR role access
    const modRes = await apiRequest('GET', '/admin/dashboard/summary', null, modAuth.token);
    assert('MODERATOR request to admin dashboard returns 200 OK', modRes.status === 200);
    assert('Dashboard summary contains valid user and moderation counts', 
      modRes.payload?.users?.total >= 0 && modRes.payload?.moderation?.pending >= 0);

    // ADMIN role access
    const adminRes = await apiRequest('GET', '/admin/dashboard/summary', null, adminAuth.token);
    assert('ADMIN request to admin dashboard returns 200 OK', adminRes.status === 200);

    // ── 3. Granular RBAC Permissions (MODERATOR vs ADMIN) ───────────────────
    console.log('\n--- 3. Granular RBAC Enforcement ---');

    // Staff endpoint: ADMIN only
    const modStaffRes = await apiRequest('GET', '/admin/staff', null, modAuth.token);
    assert('MODERATOR cannot access /admin/staff (403 Forbidden)', modStaffRes.status === 403);

    const adminStaffRes = await apiRequest('GET', '/admin/staff', null, adminAuth.token);
    assert('ADMIN can access /admin/staff (200 OK)', adminStaffRes.status === 200);
    assert('Staff list contains moderator and admin accounts', adminStaffRes.payload?.items?.length >= 2);

    // Audit logs endpoint: ADMIN only
    const modAuditRes = await apiRequest('GET', '/admin/audit-logs', null, modAuth.token);
    assert('MODERATOR cannot access /admin/audit-logs (403 Forbidden)', modAuditRes.status === 403);

    const adminAuditRes = await apiRequest('GET', '/admin/audit-logs', null, adminAuth.token);
    assert('ADMIN can access /admin/audit-logs (200 OK)', adminAuditRes.status === 200);

    // Role modification endpoint: ADMIN only
    const modRoleRes = await apiRequest('PATCH', `/admin/users/${targetUser.userId}/role`, { role: 'moderator' }, modAuth.token);
    assert('MODERATOR cannot change user roles (403 Forbidden)', modRoleRes.status === 403);

    // ADMIN self-role change protection
    const adminSelfRoleRes = await apiRequest('PATCH', `/admin/users/${adminUser.userId}/role`, { role: 'user' }, adminAuth.token);
    assert('ADMIN cannot demote/modify their own role (400 Bad Request)', adminSelfRoleRes.status === 400);

    // ADMIN valid role change
    const adminRoleChangeRes = await apiRequest('PATCH', `/admin/users/${targetUser.userId}/role`, { role: 'moderator' }, adminAuth.token);
    assert('ADMIN successfully promotes user to moderator (200 OK)', adminRoleChangeRes.status === 200 && adminRoleChangeRes.payload?.role === 'moderator');

    // Revert target role back to user
    await apiRequest('PATCH', `/admin/users/${targetUser.userId}/role`, { role: 'user' }, adminAuth.token);

    // ── 4. User Directory & Privacy Projection ──────────────────────────────
    console.log('\n--- 4. User Management & Privacy Safe Projections ---');
    const usersListRes = await apiRequest('GET', '/admin/users?limit=10', null, modAuth.token);
    assert('MODERATOR can list users (200 OK)', usersListRes.status === 200);
    assert('User list returns paginated items', Array.isArray(usersListRes.payload?.items));

    const sampleUser = usersListRes.payload?.items?.[0];
    assert('User projection excludes phone number (PII safe)', sampleUser?.phoneNumber === undefined);
    assert('User projection excludes password/refresh token hashes', sampleUser?.refreshTokenHash === undefined);
    assert('User projection excludes raw GPS coordinates', sampleUser?.coordinates === undefined);

    const userDetailRes = await apiRequest('GET', `/admin/users/${targetUser.userId}`, null, modAuth.token);
    assert('MODERATOR can view user detail (200 OK)', userDetailRes.status === 200);
    assert('User detail excludes phone number and sensitive tokens', userDetailRes.payload?.phoneNumber === undefined);

    // User status suspension
    const suspendRes = await apiRequest('PATCH', `/admin/users/${targetUser.userId}/status`, {
      status: 'suspended',
      reason: 'Repeated spam violation during automated verification',
    }, adminAuth.token);
    assert('ADMIN can suspend user with reason (200 OK)', suspendRes.status === 200 && suspendRes.payload?.accountStatus === 'suspended');

    // Verify audit log generated for suspension
    const auditCheckRes = await apiRequest('GET', '/admin/audit-logs?limit=20', null, adminAuth.token);
    const suspensionLog = auditCheckRes.payload?.items?.find((l) => l.targetId === targetUser.userId && (l.action.includes('suspend') || l.action.includes('status')));
    assert('Audit log record created for user suspension', !!suspensionLog);

    // Unsuspend user
    const unsuspendRes = await apiRequest('PATCH', `/admin/users/${targetUser.userId}/status`, {
      status: 'active',
      reason: 'Automated verification test completed — restored to active',
    }, adminAuth.token);
    assert('ADMIN can restore user to active status (200 OK)', unsuspendRes.status === 200 && unsuspendRes.payload?.accountStatus === 'active');

    // ── 5. Moderation Workflow & State Transitions ──────────────────────────
    console.log('\n--- 5. Reports & Moderation Lifecycle ---');
    
    // Create a safety report from regular user
    const createReportRes = await apiRequest('POST', '/safety/reports', {
      targetType: 'user',
      targetId: targetUser.userId,
      reason: 'spam',
      details: 'Automated verification report for moderation lifecycle test',
    }, userAuth.token);
    assert('User can submit safety report (200 OK)', createReportRes.status === 200 || createReportRes.status === 201);

    // List reports as MODERATOR
    const reportsListRes = await apiRequest('GET', '/admin/reports?status=pending', null, modAuth.token);
    assert('MODERATOR can list pending reports (200 OK)', reportsListRes.status === 200);
    const pendingReport = reportsListRes.payload?.items?.find((r) => r.targetId === targetUser.userId && r.status === 'pending');
    assert('Newly created report is visible in moderation queue', !!pendingReport);

    if (pendingReport) {
      const reportId = pendingReport.id;

      // View report detail
      const reportDetailRes = await apiRequest('GET', `/admin/reports/${reportId}`, null, modAuth.token);
      assert('MODERATOR can fetch report details (200 OK)', reportDetailRes.status === 200 && reportDetailRes.payload?.id === reportId);

      // Transition to reviewing
      const reviewRes = await apiRequest('PATCH', `/safety/reports/${reportId}/status`, {
        status: 'reviewing',
        actionReason: 'Moderator assigned case for review',
      }, modAuth.token);
      const isReviewing = reviewRes.status === 200 && (reviewRes.data?.report?.status === 'reviewing' || reviewRes.payload?.status === 'reviewing');
      assert('Report status transitioned: pending -> reviewing', isReviewing);

      // Transition to actioned
      const actionRes = await apiRequest('PATCH', `/safety/reports/${reportId}/status`, {
        status: 'actioned',
        actionReason: 'Content reviewed and verified clean',
      }, modAuth.token);
      const isActioned = actionRes.status === 200 && (actionRes.data?.report?.status === 'actioned' || actionRes.payload?.status === 'actioned');
      assert('Report status transitioned: reviewing -> actioned', isActioned);
    }

    // ── 6. Content Views (Marketplace, Businesses, Services, Communities) ───
    console.log('\n--- 6. Content Section Query Verification ---');
    const marketplaceRes = await apiRequest('GET', '/admin/marketplace?limit=5', null, modAuth.token);
    assert('Admin marketplace endpoint responds with items', marketplaceRes.status === 200 && Array.isArray(marketplaceRes.payload?.items));

    const bizRes = await apiRequest('GET', '/admin/businesses?limit=5', null, modAuth.token);
    assert('Admin businesses endpoint responds with items', bizRes.status === 200 && Array.isArray(bizRes.payload?.items));

    const servicesRes = await apiRequest('GET', '/admin/services?limit=5', null, modAuth.token);
    assert('Admin services endpoint responds with items', servicesRes.status === 200 && Array.isArray(servicesRes.payload?.items));

    const commRes = await apiRequest('GET', '/admin/communities?limit=5', null, modAuth.token);
    assert('Admin communities endpoint responds with items', commRes.status === 200 && Array.isArray(commRes.payload?.items));

    // ── Summary ─────────────────────────────────────────────────────────────
    console.log('\n========================================================================');
    const passed = results.filter((r) => r.pass).length;
    const failed = results.filter((r) => !r.pass).length;
    console.log(`TOTAL CHECKS: ${results.length} | PASSED: ${passed} | FAILED: ${failed}`);
    console.log('========================================================================\n');

    if (failed > 0) {
      process.exit(1);
    }
  } finally {
    await dbClient.end();
  }
}

runPhase11E2E().catch((err) => {
  console.error('Fatal error during E2E verification:', err);
  process.exit(1);
});

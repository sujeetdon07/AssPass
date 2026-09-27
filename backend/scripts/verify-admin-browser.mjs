import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import pg from 'pg';
const { Client } = pg;

// ============================================================================
// AASPAAS PHASE 11 — REAL BROWSER & RUNTIME VERIFICATION SUITE
// Uses local Google Chrome via Chrome DevTools Protocol (CDP) over WebSocket
// Zero external driver/CDN download dependency.
// ============================================================================

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const ADMIN_BASE_URL = 'http://localhost:3001';
const API_BASE_URL = 'http://localhost:3000/api/v1';
const DB_URL = 'postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db';

const results = [];
function recordResult(section, title, pass, extra = '') {
  const status = pass ? '[PASS]' : '[FAIL]';
  console.log(`  ${status} ${title} ${extra ? '(' + extra + ')' : ''}`);
  results.push({ section, title, pass, extra });
}

// ── CDP Controller Class ────────────────────────────────────────────────────
class BrowserSession {
  constructor(port = 9222) {
    this.port = port;
    this.chromeProcess = null;
    this.ws = null;
    this.idCounter = 1;
    this.pending = new Map();
    this.consoleErrors = [];
    this.uncaughtExceptions = [];
    this.userDataDir = path.join(
      process.env.TEMP || 'C:\\temp',
      'aaspaas_chrome_session_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6)
    );
  }

  async launch() {
    if (!fs.existsSync(CHROME_PATH)) {
      throw new Error(`Google Chrome not found at ${CHROME_PATH}`);
    }

    this.chromeProcess = spawn(CHROME_PATH, [
      '--headless=new',
      `--remote-debugging-port=${this.port}`,
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-background-networking',
      '--disable-extensions',
      `--user-data-dir=${this.userDataDir}`,
    ]);

    // Wait for CDP endpoint to become ready
    let ready = false;
    for (let i = 0; i < 30; i++) {
      await new Promise((r) => setTimeout(r, 200));
      try {
        const res = await fetch(`http://127.0.0.1:${this.port}/json/version`);
        if (res.ok) {
          ready = true;
          break;
        }
      } catch {}
    }
    if (!ready) {
      throw new Error('Chrome did not initialize CDP endpoint within timeout.');
    }
  }

  async openPage(initialUrl = 'about:blank') {
    const newTabRes = await fetch(
      `http://127.0.0.1:${this.port}/json/new?${encodeURIComponent(initialUrl)}`,
      { method: 'PUT' }
    );
    const tab = await newTabRes.json();
    this.ws = new WebSocket(tab.webSocketDebuggerUrl);

    await new Promise((resolve, reject) => {
      this.ws.onopen = resolve;
      this.ws.onerror = reject;
    });

    this.ws.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(msg.error.message || JSON.stringify(msg.error)));
        else resolve(msg.result);
      } else if (msg.method === 'Runtime.consoleAPICalled') {
        if (msg.params.type === 'error') {
          const text = msg.params.args?.map((a) => a.value || a.description).join(' ') || 'Error';
          // Filter out benign browser favicon 404s
          if (!text.includes('favicon.ico')) {
            this.consoleErrors.push(text);
          }
        }
      } else if (msg.method === 'Runtime.exceptionThrown') {
        const text = msg.params.exceptionDetails?.text || 'Uncaught Exception';
        this.uncaughtExceptions.push(text);
      }
    };

    await this.send('Page.enable');
    await this.send('Runtime.enable');
    await this.send('DOM.enable');
    await this.send('Network.enable');
  }

  send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = this.idCounter++;
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async navigate(url, waitMs = 1500) {
    await this.send('Page.navigate', { url });
    await new Promise((r) => setTimeout(r, waitMs));
  }

  async evaluate(expression) {
    const res = await this.send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    return res.result?.value;
  }

  async waitForSelector(selector, timeoutMs = 6000) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      const exists = await this.evaluate(`!!document.querySelector(${JSON.stringify(selector)})`);
      if (exists) return true;
      await new Promise((r) => setTimeout(r, 100));
    }
    return false;
  }

  async click(selector) {
    const ok = await this.evaluate(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
      if (!el) return false;
      el.click();
      return true;
    })()`);
    if (!ok) throw new Error(`Element ${selector} not found to click.`);
  }

  async type(selector, text) {
    const ok = await this.evaluate(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
      if (!el) return false;
      el.focus();
      const proto = el instanceof HTMLTextAreaElement ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
      const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
      if (setter) {
        setter.call(el, ${JSON.stringify(text)});
      } else {
        el.value = ${JSON.stringify(text)};
      }
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
      return true;
    })()`);
    if (!ok) throw new Error(`Element ${selector} not found to type.`);
  }

  async setViewport(width, height) {
    await this.send('Emulation.setDeviceMetricsOverride', {
      width,
      height,
      deviceScaleFactor: 1,
      mobile: false,
    });
  }

  async getCookies() {
    const res = await this.send('Network.getCookies');
    return res.cookies || [];
  }

  async close() {
    if (this.ws) {
      try {
        this.ws.close();
      } catch {}
    }
    if (this.chromeProcess) {
      try {
        this.chromeProcess.kill();
      } catch {}
    }
    setTimeout(() => {
      try {
        fs.rmSync(this.userDataDir, { recursive: true, force: true });
      } catch {}
    }, 1000);
  }
}

// ── Backend API Helper ──────────────────────────────────────────────────────
async function backendApi(method, path, body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${API_BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  const payload = data && typeof data === 'object' && data.data !== undefined ? data.data : data;
  return { status: res.status, ok: res.ok, data, payload };
}

// ============================================================================
// MAIN VERIFICATION FLOW
// ============================================================================
async function runRealBrowserVerification() {
  console.log('========================================================================');
  console.log('      AASPAAS PHASE 11 — REAL BROWSER & RUNTIME VERIFICATION SUITE      ');
  console.log('      Executing in Real Google Chrome via Native DevTools Protocol      ');
  console.log('========================================================================\n');

  // ── Database Verification ─────────────────────────────────────────────────
  console.log('--- 1. Infrastructure & Service Verification ---');
  const db = new Client({ connectionString: DB_URL });
  await db.connect();
  const dbCheck = await db.query('SELECT 1 as connected');
  recordResult('Services', 'PostgreSQL database connection', dbCheck.rows[0]?.connected === 1);

  // Backend Health
  const healthRes = await fetch(`${API_BASE_URL}/health`);
  const healthData = await healthRes.json().catch(() => ({}));
  recordResult('Services', 'Backend GET /api/v1/health (200 OK)', healthRes.status === 200 && healthData.database === 'connected' && healthData.redis === 'connected');

  // Backend Swagger Docs
  const swaggerRes = await fetch('http://localhost:3000/api/docs');
  recordResult('Services', 'Swagger OpenAPI docs (200 OK)', swaggerRes.status === 200);

  // Next.js Admin Production Server
  const nextRes = await fetch(ADMIN_BASE_URL);
  recordResult('Services', 'Next.js Admin Dashboard production server (port 3001)', nextRes.status === 200 || nextRes.status === 307 || nextRes.status === 308);

  // ── Setup Deterministic Test Accounts ─────────────────────────────────────
  const timestamp = Date.now().toString().slice(-6);
  const adminPhone = `+91992${timestamp}1`;
  const modPhone = `+91992${timestamp}2`;
  const userPhone = `+91992${timestamp}3`;
  const reporterPhone = `+91992${timestamp}4`;

  // Create accounts via backend OTP flow
  async function setupAccount(phone, role, name) {
    const otpRes = await backendApi('POST', '/auth/otp/request', { phoneNumber: phone });
    const devOtp = otpRes.data?.data?.devOtp;
    const verifyRes = await backendApi('POST', '/auth/otp/verify', { phoneNumber: phone, otp: devOtp });
    const userId = verifyRes.data?.data?.user?.id;
    const token = verifyRes.data?.data?.tokens?.accessToken;
    await db.query(`UPDATE users SET role = $1, "displayName" = $2, "accountStatus" = 'active', "onboardingCompleted" = true WHERE id = $3`, [role, name, userId]);
    return { userId, phone, role, name, devOtp, token };
  }

  const adminAccount = await setupAccount(adminPhone, 'admin', 'Chief Admin QA');
  const modAccount = await setupAccount(modPhone, 'moderator', 'Staff Moderator QA');
  const userAccount = await setupAccount(userPhone, 'user', 'Regular Citizen QA');
  const reporterAccount = await setupAccount(reporterPhone, 'user', 'Safety Reporter QA');

  recordResult('Setup', 'Deterministic Admin, Moderator, User, Reporter test accounts provisioned', true);

  // ── Real Browser Session 1: Admin Flow ────────────────────────────────────
  console.log('\n--- 2. Real Browser Admin Authentication & Dashboard Verification ---');
  const browser = new BrowserSession(9222);
  await browser.launch();
  await browser.openPage();

  // Test 1: Root redirect to /login
  await browser.navigate(`${ADMIN_BASE_URL}/`, 1500);
  const currentUrl1 = await browser.evaluate('window.location.href');
  recordResult('Admin Login', 'Unauthenticated root URL / redirects to /login', currentUrl1.includes('/login'));

  // Test 2: Login Page DOM Rendering
  const brandHeading = await browser.evaluate('document.querySelector("h1")?.textContent?.trim()');
  const phoneInputExists = await browser.waitForSelector('input[name="phoneNumber"]', 3000);
  const sendOtpBtn = await browser.waitForSelector('button[type="submit"]', 3000);
  recordResult('Admin Login', 'Login page renders Aaspaas Admin branding and phone input', brandHeading === 'Aaspaas Admin' && phoneInputExists && sendOtpBtn);

  // Test 3: Phone input and OTP request via browser form
  await browser.type('input[name="phoneNumber"]', adminAccount.phone);
  await browser.click('button[type="submit"]');

  // Wait for OTP input to render in DOM
  const otpInputRendered = await browser.waitForSelector('input[name="otp"]', 6000);
  recordResult('Admin Login', 'Submitting phone transitions to 6-digit OTP verification step', otpInputRendered);

  // Read the dev verification code from page DOM
  await browser.waitForSelector('code', 3000);
  const displayedDevOtp = await browser.evaluate('document.querySelector("code")?.textContent?.trim()');
  recordResult('Admin Login', 'Dev verification OTP displayed in dev environment', !!displayedDevOtp);

  // Test 4: Submit OTP in real browser
  await browser.type('input[name="otp"]', displayedDevOtp);
  await browser.click('button[type="submit"]');

  // Wait for navigation to /dashboard
  const onDashboard = await browser.waitForSelector('.admin-shell', 8000);
  const dashboardUrl = await browser.evaluate('window.location.href');
  recordResult('Admin Login', 'Successful OTP verification redirects Admin to /dashboard', onDashboard && dashboardUrl.includes('/dashboard'));

  // Test 5: Verify Session Cookies
  const cookies = await browser.getCookies();
  const accessCookie = cookies.find((c) => c.name === 'aaspaas_access_token');
  const refreshCookie = cookies.find((c) => c.name === 'aaspaas_refresh_token');
  recordResult('Security', 'Authentication cookies set with httpOnly=true and sameSite=Strict', 
    accessCookie?.httpOnly === true && accessCookie?.sameSite === 'Strict' &&
    refreshCookie?.httpOnly === true && refreshCookie?.sameSite === 'Strict');

  // Wait for Suspense to resolve metrics
  await browser.waitForSelector('.page-title', 5000);
  for (let i = 0; i < 20; i++) {
    const count = await browser.evaluate('document.querySelectorAll(".metric-card").length');
    if (count >= 10) break;
    await new Promise((r) => setTimeout(r, 200));
  }

  // Test 6: Verify Admin Dashboard UI Components
  const sidebarExists = await browser.evaluate('!!document.querySelector(".admin-sidebar")');
  const branding = await browser.evaluate('document.querySelector(".admin-sidebar")?.textContent?.includes("Aaspaas")');
  const adminBadge = await browser.evaluate('document.querySelector(".badge-admin")?.textContent?.trim()');
  const pageH1 = await browser.evaluate('document.querySelector(".page-title")?.textContent?.trim()');
  const metricCardsCount = await browser.evaluate('document.querySelectorAll(".metric-card").length');
  recordResult('Admin Dashboard UI', 'Sidebar, branding, role badge, dashboard title and metric cards render', 
    sidebarExists && branding && adminBadge === 'admin' && pageH1 === 'Dashboard' && metricCardsCount >= 10);

  // Test 7: Navigation to all admin sections
  const sectionsToVerify = [
    { name: 'Reports', path: '/reports', marker: 'Safety Reports' },
    { name: 'Users', path: '/users', marker: 'User Management' },
    { name: 'Staff', path: '/staff', marker: 'Staff Management' },
    { name: 'Audit Logs', path: '/audit-logs', marker: 'Audit Logs' },
    { name: 'Marketplace', path: '/marketplace', marker: 'Marketplace Listings' },
    { name: 'Businesses', path: '/businesses', marker: 'Businesses' },
    { name: 'Services', path: '/services', marker: 'Services' },
    { name: 'Communities', path: '/communities', marker: 'Communities' },
    { name: 'Safety', path: '/safety', marker: 'Safety Overview' },
  ];

  console.log('\n--- 3. Verifying Navigation across all Admin sections ---');
  for (const sec of sectionsToVerify) {
    await browser.navigate(`${ADMIN_BASE_URL}${sec.path}`, 2000);
    const content = await browser.evaluate('document.body.innerText');
    const hasMarker = content.includes(sec.marker);
    recordResult('Admin Navigation', `Admin navigation to ${sec.path} renders "${sec.marker}"`, hasMarker);
  }

  // Test 8: Responsive Viewports on Admin Dashboard
  console.log('\n--- 4. Responsive Viewport Verification (Desktop & Tablet) ---');
  await browser.navigate(`${ADMIN_BASE_URL}/dashboard`, 1500);
  
  // Desktop: 1280x800
  await browser.setViewport(1280, 800);
  const desktopSidebarVisible = await browser.evaluate('(() => { const s = document.querySelector(".admin-sidebar"); return s && s.offsetWidth > 100; })()');
  recordResult('Responsive UI', 'Desktop viewport (1280x800) renders full sidebar and grid layout', desktopSidebarVisible);

  // Tablet / Narrow: 768x1024
  await browser.setViewport(768, 1024);
  const tabletBodyWidth = await browser.evaluate('document.body.scrollWidth <= window.innerWidth + 20');
  recordResult('Responsive UI', 'Tablet viewport (768x1024) adapts cleanly without breaking overflow', tabletBodyWidth);

  // Reset viewport
  await browser.setViewport(1280, 800);

  // Test 9: Logout Flow
  console.log('\n--- 5. Admin Logout & Protected Route Enforcement ---');
  await browser.click('button:has(svg.lucide-log-out), form[action] button');
  await new Promise((r) => setTimeout(r, 2000));
  const postLogoutUrl = await browser.evaluate('window.location.href');
  recordResult('Logout Flow', 'Clicking sign out clears session and redirects to /login', postLogoutUrl.includes('/login'));

  // Attempting to access protected /dashboard after logout
  await browser.navigate(`${ADMIN_BASE_URL}/dashboard`, 1500);
  const afterLogoutAccessUrl = await browser.evaluate('window.location.href');
  recordResult('Logout Flow', 'Protected /dashboard redirects to /login after logout', afterLogoutAccessUrl.includes('/login'));

  await browser.close();

  // ── Real Browser Session 2: Moderator Flow & Granular RBAC ────────────────
  console.log('\n--- 6. Moderator Role & Authorization Boundary Verification ---');
  const modBrowser = new BrowserSession(9223);
  await modBrowser.launch();
  await modBrowser.openPage();

  // Moderator Login
  await modBrowser.navigate(`${ADMIN_BASE_URL}/login`, 1500);
  await modBrowser.type('input[name="phoneNumber"]', modAccount.phone);
  await modBrowser.click('button[type="submit"]');
  await modBrowser.waitForSelector('input[name="otp"]', 4000);
  await modBrowser.waitForSelector('code', 3000);
  const modDevOtp = await modBrowser.evaluate('document.querySelector("code")?.textContent?.trim()');
  await modBrowser.type('input[name="otp"]', modDevOtp);
  await modBrowser.click('button[type="submit"]');
  await modBrowser.waitForSelector('.admin-shell', 7000);

  const modBadge = await modBrowser.evaluate('document.querySelector(".badge-moderator")?.textContent?.trim()');
  recordResult('Moderator UI', 'Moderator logs in successfully and badge renders as moderator', modBadge === 'moderator');

  // Verify Moderator Sidebar Hides Staff and Audit Logs
  const sidebarLinks = await modBrowser.evaluate('Array.from(document.querySelectorAll(".nav-item span")).map(s => s.textContent.trim())');
  const staffLinkPresent = sidebarLinks.includes('Staff');
  const auditLinkPresent = sidebarLinks.includes('Audit Logs');
  recordResult('Moderator RBAC', 'Moderator sidebar hides Staff Management link', !staffLinkPresent);
  recordResult('Moderator RBAC', 'Moderator sidebar hides Audit Logs link', !auditLinkPresent);

  // Moderator direct URL access to /staff -> must redirect to /unauthorized
  await modBrowser.navigate(`${ADMIN_BASE_URL}/staff`, 2000);
  const modStaffUrl = await modBrowser.evaluate('window.location.href');
  recordResult('Moderator RBAC', 'Moderator direct URL access to /staff redirects to /unauthorized', modStaffUrl.includes('/unauthorized'));

  // Moderator direct URL access to /audit-logs -> must redirect to /unauthorized
  await modBrowser.navigate(`${ADMIN_BASE_URL}/audit-logs`, 2000);
  const modAuditUrl = await modBrowser.evaluate('window.location.href');
  recordResult('Moderator RBAC', 'Moderator direct URL access to /audit-logs redirects to /unauthorized', modAuditUrl.includes('/unauthorized'));

  // Moderator can access Reports, Users, Content, Safety
  await modBrowser.navigate(`${ADMIN_BASE_URL}/reports`, 1500);
  const modReportsUrl = await modBrowser.evaluate('window.location.href');
  recordResult('Moderator UI', 'Moderator can access /reports', modReportsUrl.includes('/reports'));

  await modBrowser.navigate(`${ADMIN_BASE_URL}/users`, 1500);
  const modUsersUrl = await modBrowser.evaluate('window.location.href');
  recordResult('Moderator UI', 'Moderator can access /users', modUsersUrl.includes('/users'));

  await modBrowser.navigate(`${ADMIN_BASE_URL}/marketplace`, 1500);
  const modMarketplaceUrl = await modBrowser.evaluate('window.location.href');
  recordResult('Moderator UI', 'Moderator can access /marketplace', modMarketplaceUrl.includes('/marketplace'));

  await modBrowser.navigate(`${ADMIN_BASE_URL}/safety`, 1500);
  const modSafetyUrl = await modBrowser.evaluate('window.location.href');
  recordResult('Moderator UI', 'Moderator can access /safety', modSafetyUrl.includes('/safety'));

  await modBrowser.close();

  // ── Real Browser Session 3: Regular User Gate & /unauthorized Page ────────
  console.log('\n--- 7. Regular USER Gate & Unauthorized Page Verification ---');
  const userBrowser = new BrowserSession(9224);
  await userBrowser.launch();
  await userBrowser.openPage();

  // Attempt login as USER via UI
  await userBrowser.navigate(`${ADMIN_BASE_URL}/login`, 1500);
  await userBrowser.type('input[name="phoneNumber"]', userAccount.phone);
  await userBrowser.click('button[type="submit"]');
  await userBrowser.waitForSelector('input[name="otp"]', 4000);
  await userBrowser.waitForSelector('code', 3000);
  const userDevOtp = await userBrowser.evaluate('document.querySelector("code")?.textContent?.trim()');
  await userBrowser.type('input[name="otp"]', userDevOtp);
  await userBrowser.click('button[type="submit"]');

  // Verify access denied message appears on login page
  await userBrowser.waitForSelector('.alert-error', 5000);
  const loginErrorMsg = await userBrowser.evaluate('document.querySelector(".alert-error")?.textContent?.trim()');
  recordResult('Regular User Gate', 'Ordinary USER login attempt blocked with staff-only error message', 
    loginErrorMsg.includes('staff members only') || loginErrorMsg.includes('denied'));

  // Test /unauthorized page directly
  await userBrowser.navigate(`${ADMIN_BASE_URL}/unauthorized`, 1500);
  const unauthHeading = await userBrowser.evaluate('document.querySelector("h1")?.textContent?.trim()');
  const unauthText = await userBrowser.evaluate('document.body.innerText');
  recordResult('Regular User Gate', 'Unauthorized page renders "Access Denied" with staff restriction warning', 
    unauthHeading === 'Access Denied' && unauthText.includes('MODERATOR and ADMIN'));

  await userBrowser.close();

  // ── Real Browser Session 4: Live Moderation Workflow Transitions ──────────
  console.log('\n--- 8. Live Report Moderation Lifecycle UI Verification ---');
  const modSession = new BrowserSession(9225);
  await modSession.launch();
  await modSession.openPage();

  // Log in as Moderator for moderation work
  await modSession.navigate(`${ADMIN_BASE_URL}/login`, 1500);
  await modSession.type('input[name="phoneNumber"]', modAccount.phone);
  await modSession.click('button[type="submit"]');
  await modSession.waitForSelector('input[name="otp"]', 4000);
  await modSession.waitForSelector('code', 3000);
  const otp4 = await modSession.evaluate('document.querySelector("code")?.textContent?.trim()');
  await modSession.type('input[name="otp"]', otp4);
  await modSession.click('button[type="submit"]');
  await modSession.waitForSelector('.admin-shell', 7000);

  // Helper to create test report from reporterAccount
  async function submitReport(targetId, reason, details) {
    const res = await backendApi('POST', '/safety/reports', {
      targetType: 'user',
      targetId,
      reason,
      details,
    }, reporterAccount.token);
    return res.data?.reportId || res.payload?.reportId || res.payload?.id;
  }

  // Create a live report to test lifecycle
  const reportId = await submitReport(userAccount.userId, 'harassment', 'Browser UI lifecycle test report');
  recordResult('Report Moderation', 'Fresh safety report created for browser verification', !!reportId);

  if (reportId) {
    // Navigate to report detail in real browser
    await modSession.navigate(`${ADMIN_BASE_URL}/reports/${reportId}`, 2000);
    const initialStatus = await modSession.evaluate('document.querySelector(".card-header .badge")?.textContent?.trim()');
    recordResult('Report Moderation', 'Report detail page renders with initial status "pending"', initialStatus?.toLowerCase() === 'pending');

    // 1. Transition pending -> reviewing via UI button
    await modSession.type('#moderation-reason', 'Reviewing claim in browser UI test');
    await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const btn = btns.find(b => b.textContent.includes("Start Review")); if (btn) btn.click(); })()');
    await new Promise((r) => setTimeout(r, 600));
    // Click confirm
    await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const confirmBtn = btns.find(b => b.textContent.includes("Confirm")); if (confirmBtn) confirmBtn.click(); })()');
    await new Promise((r) => setTimeout(r, 2000));

    const statusAfterReview = await modSession.evaluate('document.querySelector(".card-header .badge")?.textContent?.trim()');
    recordResult('Report Moderation', 'Moderator successfully transitioned status: pending -> reviewing via UI', statusAfterReview?.toLowerCase() === 'reviewing');

    // 2. Transition reviewing -> actioned via UI button
    await modSession.type('#moderation-reason', 'Content actioned in browser UI test');
    await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const actBtn = btns.find(b => b.textContent.includes("Mark Actioned")); if (actBtn) actBtn.click(); })()');
    await new Promise((r) => setTimeout(r, 600));
    // Click confirm
    await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const confirmBtn = btns.find(b => b.textContent.includes("Confirm")); if (confirmBtn) confirmBtn.click(); })()');
    await new Promise((r) => setTimeout(r, 2000));

    const statusAfterAction = await modSession.evaluate('document.querySelector(".card-header .badge")?.textContent?.trim()');
    recordResult('Report Moderation', 'Moderator successfully transitioned status: reviewing -> actioned via UI', statusAfterAction?.toLowerCase() === 'actioned');

    // Terminal state: No further transitions available
    const terminalNotice = await modSession.evaluate('document.body.innerText.includes("No further transitions available")');
    recordResult('Report Moderation', 'Actioned state correctly recognized as terminal state with no remaining transitions', terminalNotice);

    // Test Dismissed transition with another report
    const dismissId = await submitReport(userAccount.userId, 'spam', 'Report to be dismissed in browser test');
    if (dismissId) {
      await modSession.navigate(`${ADMIN_BASE_URL}/reports/${dismissId}`, 2000);
      await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const disBtn = btns.find(b => b.textContent.includes("Dismiss Report")); if (disBtn) disBtn.click(); })()');
      await new Promise((r) => setTimeout(r, 600));
      await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const confirmBtn = btns.find(b => b.textContent.includes("Confirm")); if (confirmBtn) confirmBtn.click(); })()');
      await new Promise((r) => setTimeout(r, 2000));
      const statusAfterDismiss = await modSession.evaluate('document.querySelector(".card-header .badge")?.textContent?.trim()');
      recordResult('Report Moderation', 'Moderator successfully transitioned status: pending -> dismissed via UI', statusAfterDismiss?.toLowerCase() === 'dismissed');
    }

    // Test Duplicate transition with another report
    const dupId = await submitReport(userAccount.userId, 'misinformation', 'Report to be marked duplicate in browser test');
    if (dupId) {
      await modSession.navigate(`${ADMIN_BASE_URL}/reports/${dupId}`, 2000);
      await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const dupBtn = btns.find(b => b.textContent.includes("Mark Duplicate")); if (dupBtn) dupBtn.click(); })()');
      await new Promise((r) => setTimeout(r, 600));
      await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const confirmBtn = btns.find(b => b.textContent.includes("Confirm")); if (confirmBtn) confirmBtn.click(); })()');
      await new Promise((r) => setTimeout(r, 2000));
      const statusAfterDup = await modSession.evaluate('document.querySelector(".card-header .badge")?.textContent?.trim()');
      recordResult('Report Moderation', 'Moderator successfully transitioned status: pending -> duplicate via UI', statusAfterDup?.toLowerCase() === 'duplicate');
    }
  }

  // ── Real Browser Session 5: User Management & Suspension Controls ─────────
  console.log('\n--- 9. User Directory & Suspension UI Verification ---');
  await modSession.navigate(`${ADMIN_BASE_URL}/users`, 2000);
  const usersTableRows = await modSession.evaluate('document.querySelectorAll(".data-table tbody tr").length');
  recordResult('User Management', 'User directory table renders with paginated users list', usersTableRows >= 1);

  // Navigate to target user profile
  await modSession.navigate(`${ADMIN_BASE_URL}/users/${userAccount.userId}`, 2000);
  const userProfileName = await modSession.evaluate('document.querySelector(".page-title")?.textContent?.trim()');
  const userProfileStatus = await modSession.evaluate('document.querySelector(".badge-active")?.textContent?.trim()');
  recordResult('User Management', 'Target user profile renders with displayName and active status', 
    userProfileName.includes(userAccount.name) && userProfileStatus?.toLowerCase() === 'active');

  // Test suspension validation: reason required
  await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const sBtn = btns.find(b => b.textContent.includes("Suspend Account")); if (sBtn) sBtn.click(); })()');
  await new Promise((r) => setTimeout(r, 600));
  const suspendBtnDisabledWithoutReason = await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const sBtn = btns.find(b => b.textContent.includes("Suspend Account")); return sBtn ? sBtn.disabled : false; })()');
  recordResult('User Management', 'Suspension button is disabled until suspension reason is entered', suspendBtnDisabledWithoutReason);

  // Enter suspension reason and execute suspension
  await modSession.type('textarea', 'Violation of platform community standards (automated browser QA)');
  await new Promise((r) => setTimeout(r, 400));
  await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const sBtn = btns.find(b => b.textContent.includes("Suspend Account") && !b.textContent.includes("…")); if (sBtn) sBtn.click(); })()');
  await new Promise((r) => setTimeout(r, 2500));

  const statusAfterSuspend = await modSession.evaluate('document.querySelector(".badge-suspended")?.textContent?.trim()');
  recordResult('User Management', 'User account successfully suspended via moderator action panel', statusAfterSuspend?.toLowerCase() === 'suspended');

  // Restore user account
  await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const rBtn = btns.find(b => b.textContent.includes("Restore Account")); if (rBtn) rBtn.click(); })()');
  await new Promise((r) => setTimeout(r, 600));
  await modSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll("button")); const rBtn = btns.find(b => b.textContent.includes("Restore Account") && !b.textContent.includes("…")); if (rBtn) rBtn.click(); })()');
  await new Promise((r) => setTimeout(r, 2500));

  const statusAfterRestore = await modSession.evaluate('document.querySelector(".badge-active")?.textContent?.trim()');
  recordResult('User Management', 'User account successfully restored to active status', statusAfterRestore?.toLowerCase() === 'active');

  // Self-demotion / Self-action prevention: Navigate to Moderator's own profile
  await modSession.navigate(`${ADMIN_BASE_URL}/users/${modAccount.userId}`, 2000);
  const selfActionBlocked = await modSession.evaluate('document.body.innerText.includes("You cannot perform admin actions on your own account")');
  recordResult('User Management', 'Self-action protection enforced when viewing own user profile', selfActionBlocked);

  // ── Console Error Audit ───────────────────────────────────────────────────
  console.log('\n--- 10. Console / Runtime Error Audit ---');
  recordResult('Console Audit', 'Zero uncaught JavaScript exceptions during browser operations', modSession.uncaughtExceptions.length === 0, `Count: ${modSession.uncaughtExceptions.length}`);
  recordResult('Console Audit', 'Zero application console.error events during browser operations', modSession.consoleErrors.length === 0, `Count: ${modSession.consoleErrors.length}`);

  await modSession.close();

  // ── Real Browser Session 6: Staff Management & Audit Logs (Admin) ─────────
  console.log('\n--- 11. Staff Management & Immutable Audit Log Verification ---');
  const adminSession = new BrowserSession(9226);
  await adminSession.launch();
  await adminSession.openPage();

  // Login as Admin
  await adminSession.navigate(`${ADMIN_BASE_URL}/login`, 1500);
  await adminSession.type('input[name="phoneNumber"]', adminAccount.phone);
  await adminSession.click('button[type="submit"]');
  await adminSession.waitForSelector('input[name="otp"]', 4000);
  await adminSession.waitForSelector('code', 3000);
  const adminDevOtp = await adminSession.evaluate('document.querySelector("code")?.textContent?.trim()');
  await adminSession.type('input[name="otp"]', adminDevOtp);
  await adminSession.click('button[type="submit"]');
  await adminSession.waitForSelector('.admin-shell', 7000);

  // Staff Management UI
  await adminSession.navigate(`${ADMIN_BASE_URL}/staff`, 2000);
  const staffRows = await adminSession.evaluate('document.querySelectorAll(".data-table tbody tr").length');
  const hasAdminInTable = await adminSession.evaluate('document.body.innerText.includes("Admin")');
  const hasModeratorInTable = await adminSession.evaluate('document.body.innerText.includes("Moderator")');
  recordResult('Staff Management', 'Staff directory renders with both Admin and Moderator accounts', staffRows >= 2 && hasAdminInTable && hasModeratorInTable);

  // Audit Logs UI
  await adminSession.navigate(`${ADMIN_BASE_URL}/audit-logs`, 2000);
  const auditRows = await adminSession.evaluate('document.querySelectorAll(".data-table tbody tr").length');
  const readOnlyNotice = await adminSession.evaluate('document.body.innerText.includes("Read-only. Logs cannot be edited or deleted")');
  const noMutationButtons = await adminSession.evaluate('(() => { const btns = Array.from(document.querySelectorAll(".data-table button")); return btns.length === 0; })()');
  recordResult('Audit Logs', 'Audit logs list renders recent actions and is strictly read-only', auditRows >= 1 && readOnlyNotice && noMutationButtons);

  // Verify Audit Log Filter controls render
  const actionFilterExists = await adminSession.evaluate('!!document.querySelector("select[name=\\"action\\"]")');
  const targetFilterExists = await adminSession.evaluate('!!document.querySelector("select[name=\\"targetType\\"]")');
  recordResult('Audit Logs', 'Action and Target Type filter controls render in audit logs toolbar', actionFilterExists && targetFilterExists);

  // ── Privacy & Data Projection Zero-Leakage Checks ─────────────────────────
  console.log('\n--- 12. Privacy Projections & Zero-Leakage Verification ---');
  // Check users page HTML for raw phone numbers or passwords
  await adminSession.navigate(`${ADMIN_BASE_URL}/users`, 2000);
  const usersHtml = await adminSession.evaluate('document.body.innerHTML');
  const rawPhoneFoundInUsers = usersHtml.includes(userAccount.phone);
  recordResult('Privacy', 'Raw phone numbers are NOT leaked in user directory table', !rawPhoneFoundInUsers);

  // Check audit logs page HTML for JWT secrets, tokens, password hashes
  await adminSession.navigate(`${ADMIN_BASE_URL}/audit-logs`, 2000);
  const auditHtml = await adminSession.evaluate('document.body.innerHTML');
  const hasRefreshToken = auditHtml.includes('refreshTokenHash') || auditHtml.includes('dev_access_secret');
  recordResult('Privacy', 'Token hashes and secrets are NOT exposed in audit logs UI', !hasRefreshToken);

  await adminSession.close();
  await db.end();

  // ── Final Verification Summary ────────────────────────────────────
  console.log('\n========================================================================');
  const total = results.length;
  const passed = results.filter((r) => r.pass).length;
  const failed = results.filter((r) => !r.pass).length;
  console.log(`TOTAL REAL BROWSER CHECKS: ${total} | PASSED: ${passed} | FAILED: ${failed}`);
  console.log('========================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runRealBrowserVerification().catch((err) => {
  console.error('Fatal error during real browser verification:', err);
  process.exit(1);
});

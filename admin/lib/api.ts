import { cookies } from 'next/headers';
import type {
  AuthResponse,
  CurrentAdminUser,
  PaginatedResult,
  AdminUser,
  AdminReport,
  AuditLog,
  AdminListing,
  AdminBusiness,
  AdminService,
  AdminCommunity,
  DashboardSummary,
  ApiResponse,
  UserRole,
  UserStatus,
  ReportStatus,
  ReportTargetType,
} from '@/types';

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000/api/v1';

// ── Token Management ─────────────────────────────────────────────────────────

async function getAccessToken(): Promise<string | undefined> {
  const cookieStore = await cookies();
  return cookieStore.get('aaspaas_access_token')?.value;
}

export async function setTokenCookies(
  accessToken: string,
  refreshToken: string,
  expiresIn: number,
): Promise<void> {
  const cookieStore = await cookies();
  const secure = process.env.NODE_ENV === 'production';

  cookieStore.set('aaspaas_access_token', accessToken, {
    httpOnly: true,
    secure,
    sameSite: 'strict',
    maxAge: expiresIn,
    path: '/',
  });

  // Refresh token: long-lived, httpOnly, secure, NOT accessible to JS
  cookieStore.set('aaspaas_refresh_token', refreshToken, {
    httpOnly: true,
    secure,
    sameSite: 'strict',
    maxAge: 30 * 24 * 60 * 60, // 30 days
    path: '/',
  });
}

export async function clearTokenCookies(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.delete('aaspaas_access_token');
  cookieStore.delete('aaspaas_refresh_token');
}

async function getRefreshToken(): Promise<string | undefined> {
  const cookieStore = await cookies();
  return cookieStore.get('aaspaas_refresh_token')?.value;
}

// ── Internal Fetch ────────────────────────────────────────────────────────────

interface FetchOptions {
  method?: string;
  body?: unknown;
  token?: string;
}

async function apiFetch<T>(
  path: string,
  opts: FetchOptions = {},
): Promise<T> {
  const token = opts.token ?? (await getAccessToken());

  const response = await fetch(`${API_BASE}${path}`, {
    method: opts.method ?? 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
    cache: 'no-store',
  });

  if (response.status === 401) {
    // Attempt token refresh
    const refreshToken = await getRefreshToken();
    if (refreshToken) {
      const refreshed = await tryRefreshToken(refreshToken);
      if (refreshed) {
        // Retry with new token
        const retryRes = await fetch(`${API_BASE}${path}`, {
          method: opts.method ?? 'GET',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${refreshed}`,
          },
          body: opts.body ? JSON.stringify(opts.body) : undefined,
          cache: 'no-store',
        });
        if (!retryRes.ok) {
          const err = await retryRes.json().catch(() => ({}));
          throw new ApiError(retryRes.status, (err as Record<string, string>).message ?? 'Request failed');
        }
        return retryRes.json() as Promise<T>;
      }
    }
    throw new ApiError(401, 'Session expired. Please log in again.');
  }

  if (!response.ok) {
    const err = await response.json().catch(() => ({}));
    throw new ApiError(response.status, (err as Record<string, string>).message ?? 'Request failed');
  }

  return response.json() as Promise<T>;
}

async function tryRefreshToken(refreshToken: string): Promise<string | null> {
  try {
    const res = await fetch(`${API_BASE}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
      cache: 'no-store',
    });
    if (!res.ok) return null;
    const data = (await res.json()) as { data: { accessToken: string; refreshToken: string; expiresIn: number } };
    const tokens = data.data;
    await setTokenCookies(tokens.accessToken, tokens.refreshToken, tokens.expiresIn);
    return tokens.accessToken;
  } catch {
    return null;
  }
}

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

// ── Unwrap Helper ─────────────────────────────────────────────────────────────

function unwrap<T>(response: ApiResponse<T>): T {
  return response.data;
}

// ── Auth API ──────────────────────────────────────────────────────────────────

export async function verifyOtp(
  phoneNumber: string,
  otp: string,
): Promise<AuthResponse> {
  const res = await apiFetch<ApiResponse<AuthResponse>>('/auth/otp/verify', {
    method: 'POST',
    body: { phoneNumber, otp },
  });
  return unwrap(res);
}

export async function requestOtp(phoneNumber: string): Promise<{ message: string; devOtp?: string }> {
  const res = await apiFetch<ApiResponse<{ message: string; devOtp?: string }>>('/auth/otp/request', {
    method: 'POST',
    body: { phoneNumber },
  });
  return unwrap(res);
}

export async function getCurrentUser(): Promise<CurrentAdminUser | null> {
  try {
    const res = await apiFetch<ApiResponse<CurrentAdminUser>>('/auth/me');
    const user = unwrap(res);
    // Inject role from /auth/me — backend returns it
    return user;
  } catch {
    return null;
  }
}

export async function logout(): Promise<void> {
  try {
    await apiFetch('/auth/logout', { method: 'POST' });
  } finally {
    await clearTokenCookies();
  }
}

// ── Dashboard API ─────────────────────────────────────────────────────────────

export async function getDashboardSummary(): Promise<DashboardSummary> {
  const res = await apiFetch<ApiResponse<DashboardSummary>>('/admin/dashboard/summary');
  return unwrap(res);
}

// ── Users API ─────────────────────────────────────────────────────────────────

export async function listUsers(params: {
  page?: number;
  limit?: number;
  search?: string;
  role?: UserRole;
  status?: UserStatus;
}): Promise<PaginatedResult<AdminUser>> {
  const q = new URLSearchParams();
  if (params.page) q.set('page', String(params.page));
  if (params.limit) q.set('limit', String(params.limit));
  if (params.search) q.set('search', params.search);
  if (params.role) q.set('role', params.role);
  if (params.status) q.set('status', params.status);
  const res = await apiFetch<ApiResponse<PaginatedResult<AdminUser>>>(`/admin/users?${q}`);
  return unwrap(res);
}

export async function getUserById(id: string): Promise<AdminUser> {
  const res = await apiFetch<ApiResponse<AdminUser>>(`/admin/users/${id}`);
  return unwrap(res);
}

export async function updateUserRole(id: string, role: UserRole): Promise<AdminUser> {
  const res = await apiFetch<ApiResponse<AdminUser>>(`/admin/users/${id}/role`, {
    method: 'PATCH',
    body: { role },
  });
  return unwrap(res);
}

export async function updateUserStatus(
  id: string,
  status: UserStatus,
  reason: string,
): Promise<AdminUser> {
  const res = await apiFetch<ApiResponse<AdminUser>>(`/admin/users/${id}/status`, {
    method: 'PATCH',
    body: { status, reason },
  });
  return unwrap(res);
}

// ── Reports API ───────────────────────────────────────────────────────────────

export async function listReports(params: {
  page?: number;
  limit?: number;
  status?: ReportStatus;
  targetType?: ReportTargetType;
  reason?: string;
}): Promise<PaginatedResult<AdminReport>> {
  const q = new URLSearchParams();
  if (params.page) q.set('page', String(params.page));
  if (params.limit) q.set('limit', String(params.limit));
  if (params.status) q.set('status', params.status);
  if (params.targetType) q.set('targetType', params.targetType);
  if (params.reason) q.set('reason', params.reason);
  const res = await apiFetch<ApiResponse<PaginatedResult<AdminReport>>>(`/admin/reports?${q}`);
  return unwrap(res);
}

export async function getReportById(id: string): Promise<AdminReport> {
  const res = await apiFetch<ApiResponse<AdminReport>>(`/admin/reports/${id}`);
  return unwrap(res);
}

// Use the existing safety endpoint for status updates (not a new admin endpoint)
export async function updateReportStatus(
  reportId: string,
  status: ReportStatus,
  reason?: string,
): Promise<void> {
  await apiFetch(`/safety/reports/${reportId}/status`, {
    method: 'PATCH',
    body: { status, reason },
  });
}

// ── Staff API ─────────────────────────────────────────────────────────────────

export async function listStaff(params: {
  page?: number;
  limit?: number;
}): Promise<PaginatedResult<AdminUser>> {
  const q = new URLSearchParams();
  if (params.page) q.set('page', String(params.page));
  if (params.limit) q.set('limit', String(params.limit));
  const res = await apiFetch<ApiResponse<PaginatedResult<AdminUser>>>(`/admin/staff?${q}`);
  return unwrap(res);
}

// ── Audit Logs API ────────────────────────────────────────────────────────────

export async function listAuditLogs(params: {
  page?: number;
  limit?: number;
  actorId?: string;
  action?: string;
  targetType?: string;
}): Promise<PaginatedResult<AuditLog>> {
  const q = new URLSearchParams();
  if (params.page) q.set('page', String(params.page));
  if (params.limit) q.set('limit', String(params.limit));
  if (params.actorId) q.set('actorId', params.actorId);
  if (params.action) q.set('action', params.action);
  if (params.targetType) q.set('targetType', params.targetType);
  const res = await apiFetch<ApiResponse<PaginatedResult<AuditLog>>>(`/admin/audit-logs?${q}`);
  return unwrap(res);
}

// ── Content APIs ──────────────────────────────────────────────────────────────

export async function listListings(params: {
  page?: number;
  limit?: number;
  search?: string;
}): Promise<PaginatedResult<AdminListing>> {
  const q = new URLSearchParams();
  if (params.page) q.set('page', String(params.page));
  if (params.limit) q.set('limit', String(params.limit));
  if (params.search) q.set('search', params.search);
  const res = await apiFetch<ApiResponse<PaginatedResult<AdminListing>>>(`/admin/marketplace?${q}`);
  return unwrap(res);
}

export async function listBusinesses(params: {
  page?: number;
  limit?: number;
  search?: string;
}): Promise<PaginatedResult<AdminBusiness>> {
  const q = new URLSearchParams();
  if (params.page) q.set('page', String(params.page));
  if (params.limit) q.set('limit', String(params.limit));
  if (params.search) q.set('search', params.search);
  const res = await apiFetch<ApiResponse<PaginatedResult<AdminBusiness>>>(`/admin/businesses?${q}`);
  return unwrap(res);
}

export async function listServices(params: {
  page?: number;
  limit?: number;
  search?: string;
}): Promise<PaginatedResult<AdminService>> {
  const q = new URLSearchParams();
  if (params.page) q.set('page', String(params.page));
  if (params.limit) q.set('limit', String(params.limit));
  if (params.search) q.set('search', params.search);
  const res = await apiFetch<ApiResponse<PaginatedResult<AdminService>>>(`/admin/services?${q}`);
  return unwrap(res);
}

export async function listCommunities(params: {
  page?: number;
  limit?: number;
  search?: string;
}): Promise<PaginatedResult<AdminCommunity>> {
  const q = new URLSearchParams();
  if (params.page) q.set('page', String(params.page));
  if (params.limit) q.set('limit', String(params.limit));
  if (params.search) q.set('search', params.search);
  const res = await apiFetch<ApiResponse<PaginatedResult<AdminCommunity>>>(`/admin/communities?${q}`);
  return unwrap(res);
}

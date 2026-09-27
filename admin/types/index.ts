// ── API Types ────────────────────────────────────────────────────────────────

export interface ApiResponse<T> {
  success: boolean;
  data: T;
}

export interface PaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

// ── User Types ────────────────────────────────────────────────────────────────

export type UserRole = 'user' | 'moderator' | 'admin';
export type UserStatus = 'active' | 'suspended' | 'deleted';

export interface AdminUser {
  id: string;
  displayName: string | null;
  avatarUrl: string | null;
  role: UserRole;
  accountStatus: UserStatus;
  onboardingCompleted: boolean;
  locality: string | null;
  city: string | null;
  state: string | null;
  countryCode: string | null;
  lastLoginAt: string | null;
  createdAt: string;
  updatedAt: string;
}

// ── Report Types ──────────────────────────────────────────────────────────────

export type ReportStatus = 'pending' | 'reviewing' | 'actioned' | 'dismissed' | 'duplicate';
export type ReportTargetType =
  | 'user'
  | 'post'
  | 'comment'
  | 'listing'
  | 'business'
  | 'service'
  | 'conversation'
  | 'message';

export interface AdminReport {
  id: string;
  reporterId: string;
  reporterName: string | null;
  targetType: ReportTargetType;
  targetId: string;
  reason: string;
  details: string | null;
  status: ReportStatus;
  domainReportId: string | null;
  createdAt: string;
  updatedAt: string;
  reporter?: { id: string; displayName: string | null };
}

// ── Audit Log Types ───────────────────────────────────────────────────────────

export interface AuditLog {
  id: string;
  actorId: string;
  actorName: string | null;
  action: string;
  targetType: string;
  targetId: string;
  reportId: string | null;
  reason: string | null;
  metadata: Record<string, unknown> | null;
  createdAt: string;
}

// ── Content Types ─────────────────────────────────────────────────────────────

export interface AdminListing {
  id: string;
  title: string;
  category: string;
  status: string;
  condition: string;
  price: number;
  currency: string;
  sellerId: string;
  city: string | null;
  locality: string | null;
  createdAt: string;
  deletedAt: string | null;
}

export interface AdminBusiness {
  id: string;
  name: string;
  slug: string;
  category: string;
  status: string;
  verificationStatus: string;
  ownerId: string;
  city: string | null;
  locality: string | null;
  createdAt: string;
  deletedAt: string | null;
}

export interface AdminService {
  id: string;
  title: string;
  category: string;
  status: string;
  verificationStatus: string;
  ownerId: string;
  city: string | null;
  locality: string | null;
  startingPrice: number | null;
  currency: string;
  createdAt: string;
  deletedAt: string | null;
}

export interface AdminCommunity {
  id: string;
  name: string;
  slug: string;
  category: string;
  visibility: string;
  status: string;
  memberCount: number;
  postCount: number;
  creatorId: string;
  city: string | null;
  locality: string | null;
  createdAt: string;
}

// ── Dashboard Types ───────────────────────────────────────────────────────────

export interface DashboardSummary {
  users: {
    total: number;
    active: number;
    suspended: number;
    newThisWeek: number;
  };
  moderation: {
    pending: number;
    reviewing: number;
    actioned: number;
  };
  content: {
    listings: number;
    businesses: number;
    services: number;
    communities: number;
  };
  recentActivity: AuditLog[];
}

// ── Auth Types ────────────────────────────────────────────────────────────────

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface AuthResponse {
  user: {
    id: string;
    phoneNumber: string;
    displayName: string | null;
    avatarUrl: string | null;
    onboardingCompleted: boolean;
    accountStatus: UserStatus;
  };
  tokens: AuthTokens;
}

export interface CurrentAdminUser {
  id: string;
  phoneNumber: string;
  displayName: string | null;
  avatarUrl: string | null;
  onboardingCompleted: boolean;
  accountStatus: UserStatus;
  role: UserRole;
  locality?: {
    countryCode: string | null;
    state: string | null;
    city: string | null;
    locality: string | null;
  };
}

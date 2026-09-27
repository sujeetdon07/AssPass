import type { Metadata } from 'next';
import { listUsers } from '@/lib/api';
import { PageHeader, StatusBadge, RoleBadge, EmptyState } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils';
import Link from 'next/link';
import { Users } from 'lucide-react';
import type { UserRole, UserStatus } from '@/types';

export const metadata: Metadata = { title: 'Users' };

interface UsersPageProps {
  searchParams: Promise<{
    page?: string;
    search?: string;
    role?: string;
    status?: string;
  }>;
}

export default async function UsersPage({ searchParams }: UsersPageProps) {
  const params = await searchParams;
  const page = Number(params.page ?? 1);
  const search = params.search;
  const role = params.role as UserRole | undefined;
  const status = params.status as UserStatus | undefined;

  let data;
  let fetchError: string | null = null;

  try {
    data = await listUsers({ page, limit: 25, search, role, status });
  } catch (err) {
    fetchError = err instanceof Error ? err.message : 'Failed to load users';
  }

  function buildUrl(overrides: Record<string, string | undefined>) {
    const q = new URLSearchParams();
    const merged = {
      page: String(page),
      ...(search && { search }),
      ...(role && { role }),
      ...(status && { status }),
      ...overrides,
    };
    for (const [k, v] of Object.entries(merged)) {
      if (v) q.set(k, v);
    }
    return `/users?${q}`;
  }

  return (
    <>
      <PageHeader
        title="User Management"
        description="View and manage Aaspaas user accounts. Phone numbers and credentials are never shown."
      />

      {/* Search & Filters */}
      <div className="filter-bar" style={{ marginBottom: '16px' }}>
        <form method="GET" action="/users" style={{ display: 'flex', gap: '8px', flex: 1, flexWrap: 'wrap' }}>
          <input
            type="search"
            name="search"
            className="input"
            placeholder="Search by name or user ID…"
            defaultValue={search ?? ''}
            style={{ maxWidth: '280px' }}
            aria-label="Search users"
          />
          <select name="role" className="input" defaultValue={role ?? ''} style={{ width: '140px' }} aria-label="Filter by role">
            <option value="">All Roles</option>
            <option value="user">User</option>
            <option value="moderator">Moderator</option>
            <option value="admin">Admin</option>
          </select>
          <select name="status" className="input" defaultValue={status ?? ''} style={{ width: '140px' }} aria-label="Filter by status">
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
            <option value="deleted">Deleted</option>
          </select>
          <button type="submit" className="btn btn-primary btn-sm">Apply</button>
          {(search ?? role ?? status) && (
            <Link href="/users" className="btn btn-secondary btn-sm">Clear</Link>
          )}
        </form>
      </div>

      {fetchError ? (
        <div className="alert alert-error" role="alert">{fetchError}</div>
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="data-table" aria-label="Users table">
            <thead>
              <tr>
                <th scope="col">User</th>
                <th scope="col">Role</th>
                <th scope="col">Status</th>
                <th scope="col">Locality</th>
                <th scope="col">Joined</th>
                <th scope="col" style={{ width: '80px' }}></th>
              </tr>
            </thead>
            <tbody>
              {!data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <EmptyState
                      title="No users found"
                      description={search ? `No users match "${search}"` : 'No users in the system yet.'}
                      icon={<Users />}
                    />
                  </td>
                </tr>
              ) : (
                data.items.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div
                          style={{
                            width: '32px',
                            height: '32px',
                            borderRadius: '50%',
                            background: 'var(--accent-muted)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: '13px',
                            fontWeight: '700',
                            color: 'var(--accent)',
                            flexShrink: 0,
                          }}
                          aria-hidden="true"
                        >
                          {(user.displayName ?? 'U').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: '500', fontSize: '13px' }}>
                            {user.displayName ?? <span style={{ color: 'var(--text-muted)' }}>No name</span>}
                          </div>
                          <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                            {user.id.slice(0, 8)}…
                          </div>
                        </div>
                      </div>
                    </td>
                    <td><RoleBadge role={user.role} /></td>
                    <td><StatusBadge status={user.accountStatus} /></td>
                    <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                      {user.city ?? user.locality ?? '—'}
                      {user.state && <span style={{ color: 'var(--text-muted)' }}>, {user.state}</span>}
                    </td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {formatRelativeTime(user.createdAt)}
                    </td>
                    <td>
                      <Link href={`/users/${user.id}`} className="btn btn-ghost btn-sm">
                        View
                      </Link>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>

          {data && data.totalPages > 1 && (
            <div style={{ padding: '8px 16px', borderTop: '1px solid var(--border-subtle)' }}>
              <div className="pagination">
                <span className="pagination-info">
                  {data.total.toLocaleString()} users total
                </span>
                {page > 1 && (
                  <Link href={buildUrl({ page: String(page - 1) })} className="btn btn-secondary btn-sm">← Prev</Link>
                )}
                <span style={{ fontSize: '12px', color: 'var(--text-secondary)', padding: '0 4px' }}>
                  {page} / {data.totalPages}
                </span>
                {page < data.totalPages && (
                  <Link href={buildUrl({ page: String(page + 1) })} className="btn btn-secondary btn-sm">Next →</Link>
                )}
              </div>
            </div>
          )}
        </div>
      )}
    </>
  );
}

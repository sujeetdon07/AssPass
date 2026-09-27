import type { Metadata } from 'next';
import { listStaff } from '@/lib/api';
import { requireAuth } from '@/lib/auth-actions';
import { PageHeader, StatusBadge, RoleBadge, EmptyState } from '@/components/ui';
import { formatDate } from '@/lib/utils';
import Link from 'next/link';
import { UserCog } from 'lucide-react';

export const metadata: Metadata = { title: 'Staff' };

interface StaffPageProps {
  searchParams: Promise<{ page?: string }>;
}

export default async function StaffPage({ searchParams }: StaffPageProps) {
  await requireAuth(['admin']);
  const params = await searchParams;
  const page = Number(params.page ?? 1);

  let data;
  let fetchError: string | null = null;

  try {
    data = await listStaff({ page, limit: 25 });
  } catch (err) {
    fetchError = err instanceof Error ? err.message : 'Failed to load staff';
  }

  return (
    <>
      <PageHeader
        title="Staff Management"
        description="All MODERATOR and ADMIN accounts. Role changes are ADMIN-only."
      />

      {fetchError ? (
        <div className="alert alert-error" role="alert">{fetchError}</div>
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="data-table" aria-label="Staff table">
            <thead>
              <tr>
                <th scope="col">Name</th>
                <th scope="col">Role</th>
                <th scope="col">Status</th>
                <th scope="col">City</th>
                <th scope="col">Joined</th>
                <th scope="col" style={{ width: '80px' }}></th>
              </tr>
            </thead>
            <tbody>
              {!data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <EmptyState
                      title="No staff found"
                      description="No MODERATOR or ADMIN accounts exist yet."
                      icon={<UserCog />}
                    />
                  </td>
                </tr>
              ) : (
                data.items.map((staff) => (
                  <tr key={staff.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div
                          style={{
                            width: '32px',
                            height: '32px',
                            borderRadius: '50%',
                            background: staff.role === 'admin' ? 'rgba(249, 115, 22, 0.15)' : 'var(--accent-muted)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: '13px',
                            fontWeight: '700',
                            color: staff.role === 'admin' ? '#f97316' : 'var(--accent)',
                            flexShrink: 0,
                          }}
                          aria-hidden="true"
                        >
                          {(staff.displayName ?? 'S').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: '500' }}>
                            {staff.displayName ?? '—'}
                          </div>
                          <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                            {staff.id.slice(0, 8)}…
                          </div>
                        </div>
                      </div>
                    </td>
                    <td><RoleBadge role={staff.role} /></td>
                    <td><StatusBadge status={staff.accountStatus} /></td>
                    <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                      {staff.city ?? '—'}
                    </td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {formatDate(staff.createdAt)}
                    </td>
                    <td>
                      <Link href={`/users/${staff.id}`} className="btn btn-ghost btn-sm">
                        View
                      </Link>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

import type { Metadata } from 'next';
import { getUserById } from '@/lib/api';
import { PageHeader, StatusBadge, RoleBadge } from '@/components/ui';
import { formatDate } from '@/lib/utils';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { UserActionsPanel } from './UserActionsPanel';
import { getCurrentUser } from '@/lib/api';

export const metadata: Metadata = { title: 'User Detail' };

interface UserDetailPageProps {
  params: Promise<{ id: string }>;
}

export default async function UserDetailPage({ params }: UserDetailPageProps) {
  const { id } = await params;
  const currentUser = await getCurrentUser();

  let user;
  try {
    user = await getUserById(id);
  } catch {
    notFound();
  }

  const isSelf = currentUser?.id === id;

  return (
    <>
      <PageHeader
        title={user.displayName ?? 'User Profile'}
        description={`User ID: ${user.id}`}
        actions={
          <Link href="/users" className="btn btn-secondary btn-sm">
            ← Back to Users
          </Link>
        }
      />

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: '20px', alignItems: 'start' }}>
        {/* Main info */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div className="card">
            <div className="card-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <div
                  style={{
                    width: '48px',
                    height: '48px',
                    borderRadius: '50%',
                    background: 'var(--accent-muted)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '20px',
                    fontWeight: '700',
                    color: 'var(--accent)',
                    flexShrink: 0,
                  }}
                  aria-hidden="true"
                >
                  {(user.displayName ?? 'U').charAt(0).toUpperCase()}
                </div>
                <div>
                  <h2 style={{ fontSize: '16px', fontWeight: '700' }}>
                    {user.displayName ?? 'No display name'}
                  </h2>
                  <div style={{ display: 'flex', gap: '8px', marginTop: '4px' }}>
                    <RoleBadge role={user.role} />
                    <StatusBadge status={user.accountStatus} />
                  </div>
                </div>
              </div>
            </div>

            <div className="detail-grid">
              <div className="detail-item">
                <label>User ID</label>
                <span><code style={{ fontSize: '11px', color: 'var(--accent)' }}>{user.id}</code></span>
              </div>
              <div className="detail-item">
                <label>Onboarding</label>
                <span style={{ color: user.onboardingCompleted ? 'var(--success)' : 'var(--text-muted)' }}>
                  {user.onboardingCompleted ? '✓ Completed' : 'Not completed'}
                </span>
              </div>
              <div className="detail-item">
                <label>City</label>
                <span>{user.city ?? '—'}</span>
              </div>
              <div className="detail-item">
                <label>Locality</label>
                <span>{user.locality ?? '—'}</span>
              </div>
              <div className="detail-item">
                <label>State</label>
                <span>{user.state ?? '—'}</span>
              </div>
              <div className="detail-item">
                <label>Country</label>
                <span>{user.countryCode ?? '—'}</span>
              </div>
              <div className="detail-item">
                <label>Last Login</label>
                <span>{user.lastLoginAt ? formatDate(user.lastLoginAt) : 'Never'}</span>
              </div>
              <div className="detail-item">
                <label>Joined</label>
                <span>{formatDate(user.createdAt)}</span>
              </div>
            </div>
          </div>

          {/* Privacy Notice */}
          <div
            className="alert"
            style={{
              background: 'rgba(79, 126, 248, 0.08)',
              border: '1px solid rgba(79, 126, 248, 0.2)',
              color: 'var(--text-secondary)',
              fontSize: '12px',
            }}
          >
            🔒 <strong>Privacy:</strong> Phone numbers, exact GPS coordinates, FCM tokens, 
            and authentication credentials are never displayed in the Admin Dashboard.
          </div>

          {/* Links to related data */}
          <div className="card">
            <h3 style={{ fontSize: '13px', fontWeight: '700', marginBottom: '12px' }}>
              Related Data
            </h3>
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              <Link href={`/reports?reporterId=${user.id}`} className="btn btn-secondary btn-sm">
                View Reports Filed →
              </Link>
            </div>
          </div>
        </div>

        {/* Actions Panel */}
        <div>
          <UserActionsPanel
            userId={user.id}
            currentRole={user.role}
            currentStatus={user.accountStatus}
            actorRole={currentUser?.role ?? 'user'}
            isSelf={isSelf}
          />
        </div>
      </div>
    </>
  );
}

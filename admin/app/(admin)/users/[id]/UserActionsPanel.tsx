'use client';

import { useState } from 'react';
import { actionUpdateUserRole, actionUpdateUserStatus } from '@/lib/moderation-actions';
import { useRouter } from 'next/navigation';
import type { UserRole, UserStatus } from '@/types';

interface UserActionsPanelProps {
  userId: string;
  currentRole: UserRole;
  currentStatus: UserStatus;
  actorRole: string;
  isSelf: boolean;
}

export function UserActionsPanel({
  userId,
  currentRole,
  currentStatus,
  actorRole,
  isSelf,
}: UserActionsPanelProps) {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [confirmAction, setConfirmAction] = useState<string | null>(null);
  const [suspendReason, setSuspendReason] = useState('');

  const isAdmin = actorRole === 'admin';
  const isModerator = actorRole === 'moderator' || actorRole === 'admin';

  async function handleRoleChange(newRole: UserRole) {
    setIsSubmitting(true);
    setError(null);
    setSuccess(null);
    try {
      await actionUpdateUserRole(userId, newRole);
      setSuccess(`Role updated to ${newRole} successfully.`);
      setConfirmAction(null);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Role change failed.');
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleStatusChange(newStatus: UserStatus) {
    if (!suspendReason.trim() && newStatus === 'suspended') {
      setError('Please provide a reason for suspension.');
      return;
    }
    setIsSubmitting(true);
    setError(null);
    setSuccess(null);
    try {
      await actionUpdateUserStatus(userId, newStatus, suspendReason || `Status changed to ${newStatus}`);
      setSuccess(`Account status updated to ${newStatus}.`);
      setConfirmAction(null);
      setSuspendReason('');
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Status change failed.');
    } finally {
      setIsSubmitting(false);
    }
  }

  if (isSelf) {
    return (
      <div className="card">
        <h2 style={{ fontSize: '14px', fontWeight: '700', marginBottom: '12px' }}>Actions</h2>
        <div className="alert" style={{ background: 'var(--surface-alt)', color: 'var(--text-muted)', fontSize: '12px' }}>
          You cannot perform admin actions on your own account.
        </div>
      </div>
    );
  }

  return (
    <div className="card" style={{ position: 'sticky', top: '72px' }}>
      <h2 style={{ fontSize: '14px', fontWeight: '700', marginBottom: '16px' }}>Admin Actions</h2>

      {/* Role Change — ADMIN only */}
      {isAdmin && (
        <section style={{ marginBottom: '20px' }}>
          <div
            style={{
              fontSize: '11px',
              fontWeight: '600',
              color: 'var(--text-muted)',
              textTransform: 'uppercase',
              letterSpacing: '0.5px',
              marginBottom: '8px',
            }}
          >
            Change Role
          </div>

          {confirmAction === 'role' ? (
            <div
              style={{
                background: 'var(--surface-alt)',
                borderRadius: '8px',
                padding: '12px',
                border: '1px solid var(--border)',
              }}
            >
              <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '10px' }}>
                Current role: <strong>{currentRole}</strong>. Select new role:
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {(['user', 'moderator', 'admin'] as UserRole[])
                  .filter((r) => r !== currentRole)
                  .map((r) => (
                    <button
                      key={r}
                      className={`btn btn-sm ${r === 'admin' ? 'btn-danger' : 'btn-primary'}`}
                      onClick={() => handleRoleChange(r)}
                      disabled={isSubmitting}
                      aria-label={`Change role to ${r}`}
                    >
                      {isSubmitting ? 'Processing...' : `Set as ${r}`}
                    </button>
                  ))}
              </div>
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => setConfirmAction(null)}
                style={{ marginTop: '8px', width: '100%', justifyContent: 'center' }}
              >
                Cancel
              </button>
            </div>
          ) : (
            <button
              className="btn btn-secondary"
              style={{ width: '100%', justifyContent: 'center' }}
              onClick={() => setConfirmAction('role')}
              disabled={isSubmitting}
            >
              Change Role…
            </button>
          )}
        </section>
      )}

      {/* Status Change — MODERATOR+ */}
      {isModerator && (
        <section style={{ marginBottom: '16px' }}>
          <div
            style={{
              fontSize: '11px',
              fontWeight: '600',
              color: 'var(--text-muted)',
              textTransform: 'uppercase',
              letterSpacing: '0.5px',
              marginBottom: '8px',
            }}
          >
            Account Status
          </div>

          {confirmAction === 'status' ? (
            <div
              style={{
                background: 'var(--surface-alt)',
                borderRadius: '8px',
                padding: '12px',
                border: '1px solid var(--border)',
              }}
            >
              <div style={{ marginBottom: '10px' }}>
                <textarea
                  value={suspendReason}
                  onChange={(e) => setSuspendReason(e.target.value)}
                  className="input"
                  placeholder="Reason for suspension (required)…"
                  rows={2}
                  maxLength={500}
                  style={{ resize: 'none' }}
                  aria-label="Suspension reason"
                />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {currentStatus === 'active' ? (
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={() => handleStatusChange('suspended')}
                    disabled={isSubmitting || !suspendReason.trim()}
                  >
                    {isSubmitting ? 'Processing...' : 'Suspend Account'}
                  </button>
                ) : currentStatus === 'suspended' ? (
                  <button
                    className="btn btn-primary btn-sm"
                    onClick={() => handleStatusChange('active')}
                    disabled={isSubmitting}
                  >
                    {isSubmitting ? 'Processing...' : 'Restore Account'}
                  </button>
                ) : null}
              </div>
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => { setConfirmAction(null); setSuspendReason(''); }}
                style={{ marginTop: '8px', width: '100%', justifyContent: 'center' }}
              >
                Cancel
              </button>
            </div>
          ) : (
            <button
              className={`btn ${currentStatus === 'active' ? 'btn-danger' : 'btn-primary'}`}
              style={{ width: '100%', justifyContent: 'center' }}
              onClick={() => setConfirmAction('status')}
              disabled={isSubmitting || currentStatus === 'deleted'}
            >
              {currentStatus === 'active'
                ? 'Suspend Account…'
                : currentStatus === 'suspended'
                  ? 'Restore Account…'
                  : 'Account Deleted'}
            </button>
          )}
        </section>
      )}

      {error && (
        <div className="alert alert-error" style={{ marginTop: '8px' }}>
          {error}
        </div>
      )}
      {success && (
        <div className="alert alert-success" style={{ marginTop: '8px' }}>
          {success}
        </div>
      )}

      <div
        style={{
          marginTop: '16px',
          paddingTop: '16px',
          borderTop: '1px solid var(--border-subtle)',
          fontSize: '11px',
          color: 'var(--text-muted)',
        }}
      >
        Role changes (ADMIN only) and status changes are logged to the audit trail.
      </div>
    </div>
  );
}

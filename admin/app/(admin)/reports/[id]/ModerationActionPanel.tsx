'use client';

import { useState } from 'react';
import { actionUpdateReportStatus } from '@/lib/moderation-actions';
import { statusLabel } from '@/lib/utils';
import type { ReportStatus } from '@/types';
import { useRouter } from 'next/navigation';

interface ModerationActionPanelProps {
  reportId: string;
  currentStatus: ReportStatus;
  currentUserRole: string;
}

const ALLOWED_TRANSITIONS: Record<ReportStatus, ReportStatus[]> = {
  pending: ['reviewing', 'dismissed', 'duplicate'],
  reviewing: ['actioned', 'dismissed', 'duplicate'],
  actioned: [],
  dismissed: ['reviewing'],
  duplicate: [],
};

const TRANSITION_LABELS: Record<ReportStatus, string> = {
  reviewing: 'Start Review',
  actioned: 'Mark Actioned',
  dismissed: 'Dismiss Report',
  duplicate: 'Mark Duplicate',
  pending: 'Move to Pending',
};

const TRANSITION_CLASSES: Record<ReportStatus, string> = {
  reviewing: 'btn-primary',
  actioned: 'btn-danger',
  dismissed: 'btn-secondary',
  duplicate: 'btn-secondary',
  pending: 'btn-secondary',
};

export function ModerationActionPanel({
  reportId,
  currentStatus,
  currentUserRole,
}: ModerationActionPanelProps) {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [pendingAction, setPendingAction] = useState<ReportStatus | null>(null);

  const canModerate = ['moderator', 'admin'].includes(currentUserRole);
  const transitions = ALLOWED_TRANSITIONS[currentStatus] ?? [];

  async function handleAction(newStatus: ReportStatus) {
    if (!canModerate) return;
    setIsSubmitting(true);
    setError(null);
    setSuccess(null);
    setPendingAction(null);

    try {
      await actionUpdateReportStatus(reportId, newStatus, reason || undefined);
      setSuccess(`Report successfully moved to: ${statusLabel(newStatus)}`);
      setReason('');
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Action failed. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className="card" style={{ position: 'sticky', top: '72px' }}>
      <h2 style={{ fontSize: '14px', fontWeight: '700', marginBottom: '16px' }}>
        Moderation Actions
      </h2>

      {!canModerate ? (
        <div className="alert alert-error">
          You do not have permission to perform moderation actions.
        </div>
      ) : transitions.length === 0 ? (
        <div
          style={{
            padding: '16px',
            background: 'var(--surface-alt)',
            borderRadius: '8px',
            fontSize: '12px',
            color: 'var(--text-muted)',
            textAlign: 'center',
          }}
        >
          No further transitions available for status: <strong>{statusLabel(currentStatus)}</strong>
        </div>
      ) : (
        <>
          <div style={{ marginBottom: '16px' }}>
            <label
              htmlFor="moderation-reason"
              style={{
                display: 'block',
                fontSize: '11px',
                fontWeight: '600',
                color: 'var(--text-muted)',
                textTransform: 'uppercase',
                letterSpacing: '0.5px',
                marginBottom: '6px',
              }}
            >
              Reason / Notes (optional)
            </label>
            <textarea
              id="moderation-reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              className="input"
              placeholder="Add moderation notes..."
              rows={3}
              maxLength={500}
              style={{ resize: 'vertical', minHeight: '72px' }}
              aria-label="Moderation action notes"
            />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {transitions.map((newStatus) => (
              <div key={newStatus}>
                {pendingAction === newStatus ? (
                  <div
                    style={{
                      background: 'var(--surface-alt)',
                      borderRadius: '8px',
                      padding: '12px',
                      border: '1px solid var(--border)',
                    }}
                  >
                    <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '10px' }}>
                      Confirm: <strong>{TRANSITION_LABELS[newStatus]}</strong>?
                    </p>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        className={`btn btn-sm ${TRANSITION_CLASSES[newStatus]}`}
                        onClick={() => handleAction(newStatus)}
                        disabled={isSubmitting}
                      >
                        {isSubmitting ? 'Processing...' : 'Confirm'}
                      </button>
                      <button
                        className="btn btn-ghost btn-sm"
                        onClick={() => setPendingAction(null)}
                        disabled={isSubmitting}
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                ) : (
                  <button
                    className={`btn ${TRANSITION_CLASSES[newStatus]}`}
                    style={{ width: '100%', justifyContent: 'center' }}
                    onClick={() => setPendingAction(newStatus)}
                    disabled={isSubmitting}
                    aria-label={`${TRANSITION_LABELS[newStatus]} — confirm required`}
                  >
                    {TRANSITION_LABELS[newStatus]}
                  </button>
                )}
              </div>
            ))}
          </div>
        </>
      )}

      {error && (
        <div className="alert alert-error" style={{ marginTop: '12px' }}>
          {error}
        </div>
      )}

      {success && (
        <div className="alert alert-success" style={{ marginTop: '12px' }}>
          {success}
        </div>
      )}

      {/* Info */}
      <div
        style={{
          marginTop: '16px',
          paddingTop: '16px',
          borderTop: '1px solid var(--border-subtle)',
          fontSize: '11px',
          color: 'var(--text-muted)',
          lineHeight: '1.6',
        }}
      >
        All moderation actions are logged to the audit trail. 
        Audit logs are immutable and cannot be edited.
      </div>
    </div>
  );
}

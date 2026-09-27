import type { Metadata } from 'next';
import { listAuditLogs } from '@/lib/api';
import { requireAuth } from '@/lib/auth-actions';
import { PageHeader, EmptyState } from '@/components/ui';
import { formatDate, formatRelativeTime } from '@/lib/utils';
import Link from 'next/link';
import { FileText } from 'lucide-react';

export const metadata: Metadata = { title: 'Audit Logs' };

interface AuditLogsPageProps {
  searchParams: Promise<{
    page?: string;
    actorId?: string;
    action?: string;
    targetType?: string;
  }>;
}

const ACTION_LABELS: Record<string, string> = {
  role_change: 'Role Changed',
  user_suspended: 'User Suspended',
  user_restored: 'User Restored',
  user_status_changed: 'Status Changed',
  report_submitted: 'Report Submitted',
  report_reviewed: 'Report Reviewed',
  report_actioned: 'Report Actioned',
  report_dismissed: 'Report Dismissed',
};

export default async function AuditLogsPage({ searchParams }: AuditLogsPageProps) {
  await requireAuth(['admin']);
  const params = await searchParams;
  const page = Number(params.page ?? 1);
  const actorId = params.actorId;
  const action = params.action;
  const targetType = params.targetType;

  let data;
  let fetchError: string | null = null;

  try {
    data = await listAuditLogs({ page, limit: 50, actorId, action, targetType });
  } catch (err) {
    fetchError = err instanceof Error ? err.message : 'Failed to load audit logs';
  }

  function buildUrl(overrides: Record<string, string | undefined>) {
    const q = new URLSearchParams();
    const merged = { page: String(page), ...(actorId && { actorId }), ...(action && { action }), ...(targetType && { targetType }), ...overrides };
    for (const [k, v] of Object.entries(merged)) {
      if (v) q.set(k, v);
    }
    return `/audit-logs?${q}`;
  }

  return (
    <>
      <PageHeader
        title="Audit Logs"
        description="Immutable record of all privileged admin and moderation actions."
      />

      {/* Filters */}
      <div className="filter-bar" style={{ marginBottom: '16px' }}>
        <form method="GET" action="/audit-logs" style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          <select name="action" className="input" defaultValue={action ?? ''} style={{ width: '180px' }} aria-label="Filter by action">
            <option value="">All Actions</option>
            {Object.entries(ACTION_LABELS).map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
          <select name="targetType" className="input" defaultValue={targetType ?? ''} style={{ width: '140px' }} aria-label="Filter by target type">
            <option value="">All Targets</option>
            <option value="user">User</option>
            <option value="report">Report</option>
            <option value="post">Post</option>
          </select>
          <button type="submit" className="btn btn-primary btn-sm">Apply</button>
          {(action ?? targetType ?? actorId) && (
            <Link href="/audit-logs" className="btn btn-secondary btn-sm">Clear</Link>
          )}
        </form>

        <div
          style={{
            marginLeft: 'auto',
            fontSize: '11px',
            color: 'var(--text-muted)',
            display: 'flex',
            alignItems: 'center',
            gap: '4px',
          }}
        >
          🔒 Read-only. Logs cannot be edited or deleted.
        </div>
      </div>

      {fetchError ? (
        <div className="alert alert-error" role="alert">{fetchError}</div>
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="data-table" aria-label="Audit logs table">
            <thead>
              <tr>
                <th scope="col">When</th>
                <th scope="col">Action</th>
                <th scope="col">Actor</th>
                <th scope="col">Target</th>
                <th scope="col">Report</th>
                <th scope="col">Reason</th>
              </tr>
            </thead>
            <tbody>
              {!data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <EmptyState
                      title="No audit logs found"
                      description="No admin actions have been logged yet."
                      icon={<FileText />}
                    />
                  </td>
                </tr>
              ) : (
                data.items.map((log) => (
                  <tr key={log.id}>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      <span title={formatDate(log.createdAt)}>
                        {formatRelativeTime(log.createdAt)}
                      </span>
                    </td>
                    <td>
                      <code
                        style={{
                          fontSize: '11px',
                          background: 'var(--surface-alt)',
                          padding: '2px 6px',
                          borderRadius: '4px',
                          color: 'var(--accent)',
                        }}
                      >
                        {log.action}
                      </code>
                    </td>
                    <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                      {log.actorName ?? (
                        <code style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                          {log.actorId.slice(0, 8)}…
                        </code>
                      )}
                    </td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      <span className="badge" style={{ background: 'var(--surface-alt)', color: 'var(--text-secondary)', textTransform: 'none', fontSize: '10px' }}>
                        {log.targetType}
                      </span>
                      <span style={{ marginLeft: '4px' }}>{log.targetId.slice(0, 8)}…</span>
                    </td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {log.reportId ? (
                        <Link href={`/reports/${log.reportId}`} style={{ color: 'var(--accent)' }}>
                          {log.reportId.slice(0, 8)}…
                        </Link>
                      ) : '—'}
                    </td>
                    <td style={{ fontSize: '12px', color: 'var(--text-secondary)', maxWidth: '200px' }}>
                      {log.reason ? (
                        <span title={log.reason}>
                          {log.reason.length > 40 ? log.reason.slice(0, 40) + '…' : log.reason}
                        </span>
                      ) : '—'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>

          {data && data.totalPages > 1 && (
            <div style={{ padding: '8px 16px', borderTop: '1px solid var(--border-subtle)' }}>
              <div className="pagination">
                <span className="pagination-info">{data.total.toLocaleString()} log entries</span>
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

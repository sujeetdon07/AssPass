import type { Metadata } from 'next';
import { listReports } from '@/lib/api';
import { PageHeader, StatusBadge, EmptyState } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils';
import Link from 'next/link';
import { Flag } from 'lucide-react';
import type { ReportStatus, ReportTargetType } from '@/types';

export const metadata: Metadata = { title: 'Reports' };

interface ReportsPageProps {
  searchParams: Promise<{
    page?: string;
    status?: string;
    targetType?: string;
    reason?: string;
  }>;
}

const STATUS_OPTIONS: { value: string; label: string }[] = [
  { value: '', label: 'All Statuses' },
  { value: 'pending', label: 'Pending' },
  { value: 'reviewing', label: 'Reviewing' },
  { value: 'actioned', label: 'Actioned' },
  { value: 'dismissed', label: 'Dismissed' },
  { value: 'duplicate', label: 'Duplicate' },
];

const TARGET_TYPE_OPTIONS: { value: string; label: string }[] = [
  { value: '', label: 'All Types' },
  { value: 'user', label: 'User' },
  { value: 'post', label: 'Post' },
  { value: 'comment', label: 'Comment' },
  { value: 'listing', label: 'Listing' },
  { value: 'business', label: 'Business' },
  { value: 'service', label: 'Service' },
  { value: 'conversation', label: 'Conversation' },
  { value: 'message', label: 'Message' },
];

export default async function ReportsPage({ searchParams }: ReportsPageProps) {
  const params = await searchParams;
  const page = Number(params.page ?? 1);
  const status = params.status as ReportStatus | undefined;
  const targetType = params.targetType as ReportTargetType | undefined;
  const reason = params.reason;

  let data;
  let fetchError: string | null = null;

  try {
    data = await listReports({ page, limit: 25, status, targetType, reason });
  } catch (err) {
    fetchError = err instanceof Error ? err.message : 'Failed to load reports';
  }

  function buildUrl(overrides: Record<string, string | undefined>) {
    const q = new URLSearchParams();
    const merged = { page: String(page), status, targetType, reason, ...overrides };
    for (const [k, v] of Object.entries(merged)) {
      if (v) q.set(k, v);
    }
    return `/reports?${q}`;
  }

  return (
    <>
      <PageHeader
        title="Safety Reports"
        description="All user-submitted safety reports across all content types."
      />

      {/* Filters */}
      <div className="filter-bar" role="search" aria-label="Report filters">
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          {STATUS_OPTIONS.map((opt) => (
            <Link
              key={opt.value}
              href={buildUrl({ status: opt.value || undefined, page: '1' })}
              className={`btn btn-sm ${status === opt.value || (!status && !opt.value) ? 'btn-primary' : 'btn-secondary'}`}
            >
              {opt.label}
            </Link>
          ))}
        </div>
        <div style={{ marginLeft: 'auto', display: 'flex', gap: '8px' }}>
          <select
            className="input"
            style={{ width: '160px' }}
            defaultValue={targetType ?? ''}
            aria-label="Filter by target type"
          >
            {TARGET_TYPE_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {fetchError ? (
        <div className="alert alert-error" role="alert">
          {fetchError}
        </div>
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table
            className="data-table"
            aria-label="Safety reports table"
          >
            <thead>
              <tr>
                <th scope="col">ID</th>
                <th scope="col">Status</th>
                <th scope="col">Target</th>
                <th scope="col">Reason</th>
                <th scope="col">Reporter</th>
                <th scope="col">Submitted</th>
                <th scope="col" style={{ width: '80px' }}></th>
              </tr>
            </thead>
            <tbody>
              {!data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={7}>
                    <EmptyState
                      title="No reports found"
                      description={
                        status
                          ? `No ${status} reports match your filters.`
                          : 'No safety reports have been submitted yet.'
                      }
                      icon={<Flag />}
                    />
                  </td>
                </tr>
              ) : (
                data.items.map((report) => (
                  <tr key={report.id}>
                    <td>
                      <code style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                        {report.id.slice(0, 8)}…
                      </code>
                    </td>
                    <td>
                      <StatusBadge status={report.status} />
                    </td>
                    <td>
                      <span
                        className="badge"
                        style={{
                          background: 'var(--surface-alt)',
                          color: 'var(--text-secondary)',
                          textTransform: 'none',
                          fontSize: '11px',
                        }}
                      >
                        {report.targetType}
                      </span>
                      <span
                        style={{
                          marginLeft: '6px',
                          fontSize: '11px',
                          color: 'var(--text-muted)',
                        }}
                      >
                        {report.targetId.slice(0, 8)}…
                      </span>
                    </td>
                    <td style={{ color: 'var(--text-secondary)' }}>
                      {report.reason.replace(/_/g, ' ')}
                    </td>
                    <td style={{ color: 'var(--text-secondary)', fontSize: '12px' }}>
                      {report.reporterName ?? report.reporterId.slice(0, 8) + '…'}
                    </td>
                    <td style={{ color: 'var(--text-muted)', fontSize: '11px' }}>
                      {formatRelativeTime(report.createdAt)}
                    </td>
                    <td>
                      <Link
                        href={`/reports/${report.id}`}
                        className="btn btn-ghost btn-sm"
                      >
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
                  Showing {Math.min((page - 1) * 25 + 1, data.total)}–
                  {Math.min(page * 25, data.total)} of {data.total.toLocaleString()} reports
                </span>
                {page > 1 && (
                  <Link href={buildUrl({ page: String(page - 1) })} className="btn btn-secondary btn-sm">
                    ← Prev
                  </Link>
                )}
                <span style={{ fontSize: '12px', color: 'var(--text-secondary)', padding: '0 4px' }}>
                  {page} / {data.totalPages}
                </span>
                {page < data.totalPages && (
                  <Link href={buildUrl({ page: String(page + 1) })} className="btn btn-secondary btn-sm">
                    Next →
                  </Link>
                )}
              </div>
            </div>
          )}
        </div>
      )}
    </>
  );
}

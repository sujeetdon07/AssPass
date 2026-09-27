import type { Metadata } from 'next';
import { getReportById } from '@/lib/api';
import { PageHeader, StatusBadge } from '@/components/ui';
import { formatDate } from '@/lib/utils';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ModerationActionPanel } from './ModerationActionPanel';
import { getCurrentUser } from '@/lib/api';

export const metadata: Metadata = { title: 'Report Detail' };

interface ReportDetailPageProps {
  params: Promise<{ id: string }>;
}

export default async function ReportDetailPage({ params }: ReportDetailPageProps) {
  const { id } = await params;
  const currentUser = await getCurrentUser();

  let report;
  try {
    report = await getReportById(id);
  } catch (err) {
    if (err instanceof Error && err.message.includes('not found')) {
      notFound();
    }
    throw err;
  }

  return (
    <>
      <PageHeader
        title={`Report ${id.slice(0, 8)}…`}
        description={`Safety report — ${report.targetType} / ${report.reason.replace(/_/g, ' ')}`}
        actions={
          <Link href="/reports" className="btn btn-secondary btn-sm">
            ← Back to Reports
          </Link>
        }
      />

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: '20px', alignItems: 'start' }}>
        {/* Main report info */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {/* Overview Card */}
          <div className="card">
            <div className="card-header">
              <h2 style={{ fontSize: '14px', fontWeight: '700' }}>Report Overview</h2>
              <StatusBadge status={report.status} />
            </div>

            <div className="detail-grid">
              <div className="detail-item">
                <label>Report ID</label>
                <span>
                  <code style={{ fontSize: '12px', color: 'var(--accent)' }}>{report.id}</code>
                </span>
              </div>
              <div className="detail-item">
                <label>Target Type</label>
                <span style={{ textTransform: 'capitalize' }}>{report.targetType}</span>
              </div>
              <div className="detail-item">
                <label>Target ID</label>
                <span>
                  <code style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                    {report.targetId}
                  </code>
                </span>
              </div>
              <div className="detail-item">
                <label>Reason</label>
                <span style={{ textTransform: 'capitalize' }}>
                  {report.reason.replace(/_/g, ' ')}
                </span>
              </div>
              <div className="detail-item">
                <label>Submitted</label>
                <span>{formatDate(report.createdAt)}</span>
              </div>
              <div className="detail-item">
                <label>Last Updated</label>
                <span>{formatDate(report.updatedAt)}</span>
              </div>
            </div>

            {report.details && (
              <div
                style={{
                  marginTop: '16px',
                  paddingTop: '16px',
                  borderTop: '1px solid var(--border-subtle)',
                }}
              >
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
                  Reporter Notes
                </div>
                <p
                  style={{
                    fontSize: '13px',
                    color: 'var(--text-secondary)',
                    lineHeight: '1.6',
                    background: 'var(--surface-alt)',
                    padding: '12px',
                    borderRadius: '8px',
                    borderLeft: '3px solid var(--border)',
                  }}
                >
                  {report.details}
                </p>
              </div>
            )}
          </div>

          {/* Reporter Card */}
          {report.reporter && (
            <div className="card">
              <div className="card-header">
                <h2 style={{ fontSize: '14px', fontWeight: '700' }}>Reporter</h2>
              </div>
              <div className="detail-grid">
                <div className="detail-item">
                  <label>Display Name</label>
                  <span>{report.reporter.displayName ?? 'Unknown'}</span>
                </div>
                <div className="detail-item">
                  <label>Reporter ID</label>
                  <span>
                    <code style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {report.reporterId}
                    </code>
                  </span>
                </div>
              </div>
              <Link
                href={`/users/${report.reporterId}`}
                className="btn btn-secondary btn-sm"
                style={{ marginTop: '8px' }}
              >
                View Reporter Profile →
              </Link>
            </div>
          )}

          {/* Privacy Notice for Messaging Reports */}
          {(report.targetType === 'message' || report.targetType === 'conversation') && (
            <div className="alert" style={{ background: 'rgba(79, 126, 248, 0.08)', border: '1px solid rgba(79, 126, 248, 0.2)', color: 'var(--text-secondary)' }}>
              <span style={{ fontSize: '12px' }}>
                🔒 <strong>Privacy:</strong> Private message content is not exposed through the admin dashboard. 
                Report details above contain only the reporter&apos;s notes. 
                Access to message content requires additional authorization through separate investigation procedures.
              </span>
            </div>
          )}
        </div>

        {/* Moderation Action Panel */}
        <div>
          <ModerationActionPanel
            reportId={report.id}
            currentStatus={report.status}
            currentUserRole={currentUser?.role ?? 'user'}
          />
        </div>
      </div>
    </>
  );
}

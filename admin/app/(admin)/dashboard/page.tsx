import type { Metadata } from 'next';
import { getDashboardSummary } from '@/lib/api';
import { PageHeader, SkeletonCard } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils';
import { Suspense } from 'react';
import {
  Users,
  Flag,
  ShoppingBag,
  Building2,
  Wrench,
  Users2,
  AlertCircle,
  Eye,
  CheckCircle2,
  UserPlus,
} from 'lucide-react';

export const metadata: Metadata = { title: 'Dashboard' };

async function DashboardMetrics() {
  let data;
  try {
    data = await getDashboardSummary();
  } catch {
    return (
      <div className="alert alert-error" role="alert">
        Failed to load dashboard data. Please try refreshing.
      </div>
    );
  }

  return (
    <>
      {/* User Metrics */}
      <section aria-labelledby="users-heading">
        <h2
          id="users-heading"
          style={{
            fontSize: '12px',
            fontWeight: '700',
            color: 'var(--text-muted)',
            textTransform: 'uppercase',
            letterSpacing: '1px',
            marginBottom: '12px',
          }}
        >
          Users
        </h2>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: '12px',
            marginBottom: '24px',
          }}
        >
          <MetricCard
            label="Total Users"
            value={data.users.total.toLocaleString()}
            sub="All registered accounts"
            icon={<Users size={18} style={{ color: 'var(--accent)' }} />}
          />
          <MetricCard
            label="Active Users"
            value={data.users.active.toLocaleString()}
            sub="Currently active accounts"
            icon={<CheckCircle2 size={18} style={{ color: 'var(--success)' }} />}
          />
          <MetricCard
            label="New This Week"
            value={data.users.newThisWeek.toLocaleString()}
            sub="Registered in last 7 days"
            icon={<UserPlus size={18} style={{ color: '#a855f7' }} />}
          />
          <MetricCard
            label="Suspended"
            value={data.users.suspended.toLocaleString()}
            sub="Suspended accounts"
            icon={<AlertCircle size={18} style={{ color: 'var(--danger)' }} />}
          />
        </div>
      </section>

      {/* Moderation Metrics */}
      <section aria-labelledby="moderation-heading">
        <h2
          id="moderation-heading"
          style={{
            fontSize: '12px',
            fontWeight: '700',
            color: 'var(--text-muted)',
            textTransform: 'uppercase',
            letterSpacing: '1px',
            marginBottom: '12px',
          }}
        >
          Moderation Queue
        </h2>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: '12px',
            marginBottom: '24px',
          }}
        >
          <MetricCard
            label="Pending Reports"
            value={data.moderation.pending.toLocaleString()}
            sub="Awaiting first review"
            icon={<Flag size={18} style={{ color: 'var(--warning)' }} />}
            highlight={data.moderation.pending > 0 ? 'warning' : undefined}
          />
          <MetricCard
            label="Under Review"
            value={data.moderation.reviewing.toLocaleString()}
            sub="Currently being reviewed"
            icon={<Eye size={18} style={{ color: '#3b82f6' }} />}
            highlight={data.moderation.reviewing > 0 ? 'info' : undefined}
          />
          <MetricCard
            label="Actioned"
            value={data.moderation.actioned.toLocaleString()}
            sub="Reports actioned"
            icon={<CheckCircle2 size={18} style={{ color: 'var(--success)' }} />}
          />
        </div>
      </section>

      {/* Content Metrics */}
      <section aria-labelledby="content-heading">
        <h2
          id="content-heading"
          style={{
            fontSize: '12px',
            fontWeight: '700',
            color: 'var(--text-muted)',
            textTransform: 'uppercase',
            letterSpacing: '1px',
            marginBottom: '12px',
          }}
        >
          Content
        </h2>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: '12px',
            marginBottom: '32px',
          }}
        >
          <MetricCard
            label="Listings"
            value={data.content.listings.toLocaleString()}
            sub="Marketplace listings"
            icon={<ShoppingBag size={18} style={{ color: '#f97316' }} />}
          />
          <MetricCard
            label="Businesses"
            value={data.content.businesses.toLocaleString()}
            sub="Registered businesses"
            icon={<Building2 size={18} style={{ color: '#06b6d4' }} />}
          />
          <MetricCard
            label="Services"
            value={data.content.services.toLocaleString()}
            sub="Service listings"
            icon={<Wrench size={18} style={{ color: '#a855f7' }} />}
          />
          <MetricCard
            label="Communities"
            value={data.content.communities.toLocaleString()}
            sub="Active communities"
            icon={<Users2 size={18} style={{ color: '#22d3ee' }} />}
          />
        </div>
      </section>

      {/* Recent Activity */}
      {data.recentActivity.length > 0 && (
        <section aria-labelledby="activity-heading">
          <div className="card">
            <div className="card-header">
              <h2
                id="activity-heading"
                style={{ fontSize: '14px', fontWeight: '700' }}
              >
                Recent Moderation Activity
              </h2>
            </div>
            <table className="data-table" aria-label="Recent moderation activity">
              <thead>
                <tr>
                  <th scope="col">Action</th>
                  <th scope="col">Actor</th>
                  <th scope="col">Target</th>
                  <th scope="col">When</th>
                </tr>
              </thead>
              <tbody>
                {data.recentActivity.map((log) => (
                  <tr key={log.id}>
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
                    <td style={{ color: 'var(--text-secondary)' }}>
                      {log.actorName ?? log.actorId.slice(0, 8) + '…'}
                    </td>
                    <td style={{ color: 'var(--text-secondary)', fontSize: '11px' }}>
                      {log.targetType}/{log.targetId.slice(0, 8)}…
                    </td>
                    <td style={{ color: 'var(--text-muted)', fontSize: '11px' }}>
                      {formatRelativeTime(log.createdAt)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </>
  );
}

function MetricCard({
  label,
  value,
  sub,
  icon,
  highlight,
}: {
  label: string;
  value: string;
  sub: string;
  icon: React.ReactNode;
  highlight?: 'warning' | 'info';
}) {
  return (
    <div
      className="metric-card"
      style={{
        borderColor:
          highlight === 'warning'
            ? 'rgba(245, 158, 11, 0.3)'
            : highlight === 'info'
              ? 'rgba(59, 130, 246, 0.3)'
              : undefined,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        {icon}
        <span className="metric-label">{label}</span>
      </div>
      <div className="metric-value">{value}</div>
      <div className="metric-sub">{sub}</div>
    </div>
  );
}

function DashboardSkeleton() {
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(4, 1fr)',
        gap: '12px',
      }}
    >
      {Array.from({ length: 8 }).map((_, i) => (
        <SkeletonCard key={i} />
      ))}
    </div>
  );
}

export default function DashboardPage() {
  return (
    <>
      <PageHeader
        title="Dashboard"
        description="Real-time overview of Aaspaas platform health and moderation status."
      />
      <Suspense fallback={<DashboardSkeleton />}>
        <DashboardMetrics />
      </Suspense>
    </>
  );
}

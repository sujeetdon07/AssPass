import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = { title: 'Safety Overview' };

export default function SafetyPage() {
  return (
    <>
      <div
        style={{
          display: 'flex',
          alignItems: 'flex-start',
          justifyContent: 'space-between',
          marginBottom: '24px',
          flexWrap: 'wrap',
          gap: '16px',
        }}
      >
        <div>
          <h1 className="page-title">Safety Overview</h1>
          <p className="page-description">
            Trust &amp; Safety module — quick links and status overview.
          </p>
        </div>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: '16px',
        }}
      >
        <QuickLink
          href="/reports?status=pending"
          title="Pending Reports"
          description="Review safety reports awaiting moderation action."
          iconColor="#f59e0b"
          icon="🚩"
        />
        <QuickLink
          href="/reports?status=reviewing"
          title="Under Review"
          description="Reports currently being reviewed by the moderation team."
          iconColor="#3b82f6"
          icon="👁"
        />
        <QuickLink
          href="/users?status=suspended"
          title="Suspended Users"
          description="View and manage suspended user accounts."
          iconColor="#ef4444"
          icon="⛔"
        />
        <QuickLink
          href="/audit-logs"
          title="Audit Trail"
          description="Immutable log of all moderation and admin actions."
          iconColor="#22c55e"
          icon="📋"
        />
      </div>

      <div
        className="card"
        style={{ marginTop: '24px' }}
      >
        <h2 style={{ fontSize: '14px', fontWeight: '700', marginBottom: '12px' }}>
          Phase 10 Trust &amp; Safety Architecture
        </h2>
        <div
          style={{
            fontSize: '13px',
            color: 'var(--text-secondary)',
            lineHeight: '1.7',
          }}
        >
          <p>The Aaspaas Trust &amp; Safety system (Phase 10) provides:</p>
          <ul style={{ paddingLeft: '20px', marginTop: '8px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <li>Centralized safety reports across all content types (posts, comments, listings, businesses, services, users, conversations)</li>
            <li>Moderation status lifecycle: <code style={{ color: 'var(--accent)', background: 'var(--surface-alt)', padding: '1px 4px', borderRadius: '3px' }}>pending → reviewing → actioned / dismissed / duplicate</code></li>
            <li>Immutable moderation audit log for all privileged actions</li>
            <li>User blocking system with bidirectional enforcement</li>
            <li>Rate-limited report submission (10 per hour per user)</li>
          </ul>
        </div>
      </div>
    </>
  );
}

function QuickLink({ href, title, description, iconColor, icon }: {
  href: string;
  title: string;
  description: string;
  iconColor: string;
  icon: string;
}) {
  return (
    <Link
      href={href}
      style={{ textDecoration: 'none' }}
    >
      <div
        className="card"
        style={{
          cursor: 'pointer',
          transition: 'border-color 0.15s, box-shadow 0.15s',
          display: 'flex',
          gap: '14px',
          alignItems: 'flex-start',
        }}
      >
        <div
          style={{
            width: '40px',
            height: '40px',
            borderRadius: '10px',
            background: `${iconColor}15`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '20px',
            flexShrink: 0,
          }}
          aria-hidden="true"
        >
          {icon}
        </div>
        <div>
          <div style={{ fontWeight: '700', fontSize: '14px', color: 'var(--text-primary)', marginBottom: '4px' }}>
            {title}
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', lineHeight: '1.5' }}>
            {description}
          </div>
        </div>
      </div>
    </Link>
  );
}

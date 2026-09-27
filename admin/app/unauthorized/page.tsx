import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Unauthorized' };

export default function UnauthorizedPage() {
  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--background)',
        padding: '24px',
      }}
    >
      <div style={{ textAlign: 'center', maxWidth: '400px' }}>
        <div
          style={{
            fontSize: '64px',
            marginBottom: '16px',
          }}
          role="img"
          aria-label="Lock emoji"
        >
          🔒
        </div>
        <h1
          style={{
            fontSize: '24px',
            fontWeight: '700',
            color: 'var(--text-primary)',
            marginBottom: '8px',
          }}
        >
          Access Denied
        </h1>
        <p
          style={{
            fontSize: '14px',
            color: 'var(--text-muted)',
            marginBottom: '24px',
            lineHeight: '1.6',
          }}
        >
          You do not have permission to access the Aaspaas Admin Dashboard.
          This area is restricted to MODERATOR and ADMIN roles only.
          This access attempt has been logged.
        </p>
        <Link href="/login" className="btn btn-primary" style={{ display: 'inline-flex' }}>
          Back to Login
        </Link>
      </div>
    </div>
  );
}

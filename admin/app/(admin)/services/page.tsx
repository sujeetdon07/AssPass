import type { Metadata } from 'next';
import { listServices } from '@/lib/api';
import { PageHeader, EmptyState } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils';
import Link from 'next/link';
import { Wrench } from 'lucide-react';

export const metadata: Metadata = { title: 'Services' };

interface PageProps {
  searchParams: Promise<{ page?: string; search?: string }>;
}

export default async function ServicesPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const page = Number(params.page ?? 1);
  const search = params.search;

  let data;
  let fetchError: string | null = null;

  try {
    data = await listServices({ page, limit: 25, search });
  } catch (err) {
    fetchError = err instanceof Error ? err.message : 'Failed to load services';
  }

  function buildUrl(overrides: Record<string, string | undefined>) {
    const q = new URLSearchParams();
    const merged = { page: String(page), ...(search && { search }), ...overrides };
    for (const [k, v] of Object.entries(merged)) { if (v) q.set(k, v); }
    return `/services?${q}`;
  }

  return (
    <>
      <PageHeader title="Services" description="All service listings on the platform." />

      <div className="filter-bar" style={{ marginBottom: '16px' }}>
        <form method="GET" action="/services" style={{ display: 'flex', gap: '8px' }}>
          <input type="search" name="search" className="input" placeholder="Search services…" defaultValue={search ?? ''} style={{ maxWidth: '280px' }} aria-label="Search services" />
          <button type="submit" className="btn btn-primary btn-sm">Search</button>
          {search && <Link href="/services" className="btn btn-secondary btn-sm">Clear</Link>}
        </form>
      </div>

      {fetchError ? (
        <div className="alert alert-error" role="alert">{fetchError}</div>
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="data-table" aria-label="Services table">
            <thead>
              <tr>
                <th scope="col">Title</th>
                <th scope="col">Category</th>
                <th scope="col">Status</th>
                <th scope="col">Verification</th>
                <th scope="col">Starting Price</th>
                <th scope="col">Location</th>
                <th scope="col">Listed</th>
              </tr>
            </thead>
            <tbody>
              {!data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={7}><EmptyState title="No services found" icon={<Wrench />} /></td>
                </tr>
              ) : (
                data.items.map((s) => (
                  <tr key={s.id} style={{ opacity: s.deletedAt ? 0.6 : 1 }}>
                    <td style={{ fontWeight: '500' }}>{s.title}</td>
                    <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{s.category.replace(/_/g, ' ')}</td>
                    <td><span className={`badge badge-${s.status === 'active' ? 'active' : 'dismissed'}`}>{s.status}</span></td>
                    <td><span className={`badge ${s.verificationStatus === 'verified' ? 'badge-actioned' : s.verificationStatus === 'pending' ? 'badge-pending' : 'badge-dismissed'}`}>{s.verificationStatus}</span></td>
                    <td style={{ fontSize: '12px' }}>{s.startingPrice ? `${s.currency} ${Number(s.startingPrice).toLocaleString()}` : '—'}</td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{s.city ?? '—'}</td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{formatRelativeTime(s.createdAt)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          {data && data.totalPages > 1 && (
            <div style={{ padding: '8px 16px', borderTop: '1px solid var(--border-subtle)' }}>
              <div className="pagination">
                <span className="pagination-info">{data.total.toLocaleString()} services</span>
                {page > 1 && <Link href={buildUrl({ page: String(page - 1) })} className="btn btn-secondary btn-sm">← Prev</Link>}
                <span style={{ fontSize: '12px', color: 'var(--text-secondary)', padding: '0 4px' }}>{page} / {data.totalPages}</span>
                {page < data.totalPages && <Link href={buildUrl({ page: String(page + 1) })} className="btn btn-secondary btn-sm">Next →</Link>}
              </div>
            </div>
          )}
        </div>
      )}
    </>
  );
}

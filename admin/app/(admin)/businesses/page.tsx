import type { Metadata } from 'next';
import { listBusinesses } from '@/lib/api';
import { PageHeader, EmptyState } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils';
import Link from 'next/link';
import { Building2 } from 'lucide-react';

export const metadata: Metadata = { title: 'Businesses' };

interface PageProps {
  searchParams: Promise<{ page?: string; search?: string }>;
}

export default async function BusinessesPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const page = Number(params.page ?? 1);
  const search = params.search;

  let data;
  let fetchError: string | null = null;

  try {
    data = await listBusinesses({ page, limit: 25, search });
  } catch (err) {
    fetchError = err instanceof Error ? err.message : 'Failed to load businesses';
  }

  function buildUrl(overrides: Record<string, string | undefined>) {
    const q = new URLSearchParams();
    const merged = { page: String(page), ...(search && { search }), ...overrides };
    for (const [k, v] of Object.entries(merged)) {
      if (v) q.set(k, v);
    }
    return `/businesses?${q}`;
  }

  return (
    <>
      <PageHeader
        title="Businesses"
        description="All business listings including verification status."
      />

      <div className="filter-bar" style={{ marginBottom: '16px' }}>
        <form method="GET" action="/businesses" style={{ display: 'flex', gap: '8px' }}>
          <input
            type="search"
            name="search"
            className="input"
            placeholder="Search businesses…"
            defaultValue={search ?? ''}
            style={{ maxWidth: '280px' }}
            aria-label="Search businesses"
          />
          <button type="submit" className="btn btn-primary btn-sm">Search</button>
          {search && <Link href="/businesses" className="btn btn-secondary btn-sm">Clear</Link>}
        </form>
      </div>

      {fetchError ? (
        <div className="alert alert-error" role="alert">{fetchError}</div>
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="data-table" aria-label="Businesses table">
            <thead>
              <tr>
                <th scope="col">Name</th>
                <th scope="col">Category</th>
                <th scope="col">Status</th>
                <th scope="col">Verification</th>
                <th scope="col">Location</th>
                <th scope="col">Added</th>
              </tr>
            </thead>
            <tbody>
              {!data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <EmptyState title="No businesses found" icon={<Building2 />} />
                  </td>
                </tr>
              ) : (
                data.items.map((b) => (
                  <tr key={b.id} style={{ opacity: b.deletedAt ? 0.6 : 1 }}>
                    <td>
                      <div style={{ fontWeight: '500' }}>{b.name}</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{b.slug}</div>
                    </td>
                    <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                      {b.category.replace(/_/g, ' ')}
                    </td>
                    <td>
                      <span className={`badge badge-${b.status === 'active' ? 'active' : 'dismissed'}`}>
                        {b.status}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${b.verificationStatus === 'verified' ? 'badge-actioned' : b.verificationStatus === 'pending' ? 'badge-pending' : 'badge-dismissed'}`}>
                        {b.verificationStatus}
                      </span>
                    </td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {b.city ?? '—'}
                    </td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {formatRelativeTime(b.createdAt)}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          {data && data.totalPages > 1 && (
            <div style={{ padding: '8px 16px', borderTop: '1px solid var(--border-subtle)' }}>
              <div className="pagination">
                <span className="pagination-info">{data.total.toLocaleString()} businesses</span>
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

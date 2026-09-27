import type { Metadata } from 'next';
import { listListings } from '@/lib/api';
import { PageHeader, EmptyState } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils';
import Link from 'next/link';
import { ShoppingBag } from 'lucide-react';

export const metadata: Metadata = { title: 'Marketplace' };

interface PageProps {
  searchParams: Promise<{ page?: string; search?: string }>;
}

export default async function MarketplacePage({ searchParams }: PageProps) {
  const params = await searchParams;
  const page = Number(params.page ?? 1);
  const search = params.search;

  let data;
  let fetchError: string | null = null;

  try {
    data = await listListings({ page, limit: 25, search });
  } catch (err) {
    fetchError = err instanceof Error ? err.message : 'Failed to load listings';
  }

  function buildUrl(overrides: Record<string, string | undefined>) {
    const q = new URLSearchParams();
    const merged = { page: String(page), ...(search && { search }), ...overrides };
    for (const [k, v] of Object.entries(merged)) {
      if (v) q.set(k, v);
    }
    return `/marketplace?${q}`;
  }

  return (
    <>
      <PageHeader
        title="Marketplace Listings"
        description="All marketplace listings including soft-deleted entries."
      />

      <div className="filter-bar" style={{ marginBottom: '16px' }}>
        <form method="GET" action="/marketplace" style={{ display: 'flex', gap: '8px' }}>
          <input
            type="search"
            name="search"
            className="input"
            placeholder="Search listings…"
            defaultValue={search ?? ''}
            style={{ maxWidth: '280px' }}
            aria-label="Search listings"
          />
          <button type="submit" className="btn btn-primary btn-sm">Search</button>
          {search && <Link href="/marketplace" className="btn btn-secondary btn-sm">Clear</Link>}
        </form>
      </div>

      {fetchError ? (
        <div className="alert alert-error" role="alert">{fetchError}</div>
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="data-table" aria-label="Marketplace listings table">
            <thead>
              <tr>
                <th scope="col">Title</th>
                <th scope="col">Category</th>
                <th scope="col">Price</th>
                <th scope="col">Status</th>
                <th scope="col">Location</th>
                <th scope="col">Listed</th>
                <th scope="col">Deleted</th>
              </tr>
            </thead>
            <tbody>
              {!data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={7}>
                    <EmptyState title="No listings found" icon={<ShoppingBag />} />
                  </td>
                </tr>
              ) : (
                data.items.map((l) => (
                  <tr key={l.id} style={{ opacity: l.deletedAt ? 0.6 : 1 }}>
                    <td style={{ fontWeight: '500', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {l.title}
                    </td>
                    <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                      {l.category.replace(/_/g, ' ')}
                    </td>
                    <td style={{ fontSize: '12px' }}>
                      {l.currency} {Number(l.price).toLocaleString()}
                    </td>
                    <td>
                      <span className={`badge badge-${l.status === 'active' ? 'active' : 'dismissed'}`}>
                        {l.status}
                      </span>
                    </td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {l.city ?? l.locality ?? '—'}
                    </td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {formatRelativeTime(l.createdAt)}
                    </td>
                    <td style={{ fontSize: '11px', color: l.deletedAt ? 'var(--danger)' : 'var(--text-muted)' }}>
                      {l.deletedAt ? formatRelativeTime(l.deletedAt) : '—'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          {data && data.totalPages > 1 && (
            <div style={{ padding: '8px 16px', borderTop: '1px solid var(--border-subtle)' }}>
              <div className="pagination">
                <span className="pagination-info">{data.total.toLocaleString()} listings</span>
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

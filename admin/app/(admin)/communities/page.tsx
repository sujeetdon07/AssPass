import type { Metadata } from 'next';
import { listCommunities } from '@/lib/api';
import { PageHeader, EmptyState } from '@/components/ui';
import { formatRelativeTime } from '@/lib/utils';
import Link from 'next/link';
import { Users2 } from 'lucide-react';

export const metadata: Metadata = { title: 'Communities' };

interface PageProps {
  searchParams: Promise<{ page?: string; search?: string }>;
}

export default async function CommunitiesPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const page = Number(params.page ?? 1);
  const search = params.search;

  let data;
  let fetchError: string | null = null;

  try {
    data = await listCommunities({ page, limit: 25, search });
  } catch (err) {
    fetchError = err instanceof Error ? err.message : 'Failed to load communities';
  }

  function buildUrl(overrides: Record<string, string | undefined>) {
    const q = new URLSearchParams();
    const merged = { page: String(page), ...(search && { search }), ...overrides };
    for (const [k, v] of Object.entries(merged)) { if (v) q.set(k, v); }
    return `/communities?${q}`;
  }

  return (
    <>
      <PageHeader title="Communities" description="All Aaspaas community groups." />

      <div className="filter-bar" style={{ marginBottom: '16px' }}>
        <form method="GET" action="/communities" style={{ display: 'flex', gap: '8px' }}>
          <input type="search" name="search" className="input" placeholder="Search communities…" defaultValue={search ?? ''} style={{ maxWidth: '280px' }} aria-label="Search communities" />
          <button type="submit" className="btn btn-primary btn-sm">Search</button>
          {search && <Link href="/communities" className="btn btn-secondary btn-sm">Clear</Link>}
        </form>
      </div>

      {fetchError ? (
        <div className="alert alert-error" role="alert">{fetchError}</div>
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="data-table" aria-label="Communities table">
            <thead>
              <tr>
                <th scope="col">Name</th>
                <th scope="col">Category</th>
                <th scope="col">Status</th>
                <th scope="col">Visibility</th>
                <th scope="col">Members</th>
                <th scope="col">Posts</th>
                <th scope="col">Location</th>
                <th scope="col">Created</th>
              </tr>
            </thead>
            <tbody>
              {!data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={8}><EmptyState title="No communities found" icon={<Users2 />} /></td>
                </tr>
              ) : (
                data.items.map((c) => (
                  <tr key={c.id}>
                    <td>
                      <div style={{ fontWeight: '500' }}>{c.name}</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{c.slug}</div>
                    </td>
                    <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{c.category.replace(/_/g, ' ')}</td>
                    <td><span className={`badge badge-${c.status === 'active' ? 'active' : 'dismissed'}`}>{c.status}</span></td>
                    <td><span className={`badge ${c.visibility === 'public' ? 'badge-actioned' : 'badge-pending'}`}>{c.visibility}</span></td>
                    <td style={{ fontSize: '12px' }}>{c.memberCount.toLocaleString()}</td>
                    <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{c.postCount.toLocaleString()}</td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{c.city ?? '—'}</td>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{formatRelativeTime(c.createdAt)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          {data && data.totalPages > 1 && (
            <div style={{ padding: '8px 16px', borderTop: '1px solid var(--border-subtle)' }}>
              <div className="pagination">
                <span className="pagination-info">{data.total.toLocaleString()} communities</span>
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

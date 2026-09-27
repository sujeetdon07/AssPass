'use client';

import { useState, useCallback } from 'react';

// Simple SWR-like hook using React state + useEffect to avoid adding SWR dep
export function usePaginated<T>(
  fetcher: (params: { page: number; limit: number }) => Promise<T>,
  initialLimit = 20,
) {
  const [page, setPage] = useState(1);
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(
    async (p: number) => {
      setLoading(true);
      setError(null);
      try {
        const result = await fetcher({ page: p, limit: initialLimit });
        setData(result);
        setPage(p);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load data');
      } finally {
        setLoading(false);
      }
    },
    [fetcher, initialLimit],
  );

  return { data, loading, error, page, load, setPage };
}

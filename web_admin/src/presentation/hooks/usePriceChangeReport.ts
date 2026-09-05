import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import {
  priceChangeRowsInRange,
  type PriceChangeRow,
} from '@/domain/products/priceChangeReport';
import type { DateRange } from '@/domain/reports/dateRange';

/** Admin-only cross-product price/cost changes over [range], as delta rows.
 *  `enabled: false` (a viewer without viewProductCost on the index) skips the
 *  query entirely and reports an empty, non-loading result. */
export function usePriceChangeReport(
  range: DateRange,
  { enabled = true }: { enabled?: boolean } = {},
): {
  rows: PriceChangeRow[];
  isLoading: boolean;
  error: Error | null;
  refetch: () => void;
} {
  const repo = useProductRepo();
  const q = useQuery({
    queryKey: ['reports', 'price-changes', range.start.getTime(), range.end.getTime()],
    queryFn: () => repo.listPriceChangesInRange(range.start, range.end),
    enabled,
  });
  const rows = useMemo(() => (q.data ? priceChangeRowsInRange(q.data) : []), [q.data]);
  return {
    rows,
    isLoading: enabled && q.isLoading,
    error: (q.error as Error) ?? null,
    refetch: () => void q.refetch(),
  };
}

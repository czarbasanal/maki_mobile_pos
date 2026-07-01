import { useQuery } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import {
  priceChangeRowsInRange,
  type PriceChangeRow,
} from '@/domain/products/priceChangeReport';
import type { DateRange } from '@/domain/reports/dateRange';

/** Admin-only cross-product price/cost changes over [range], as delta rows. */
export function usePriceChangeReport(range: DateRange): {
  rows: PriceChangeRow[];
  isLoading: boolean;
  error: Error | null;
} {
  const repo = useProductRepo();
  const q = useQuery({
    queryKey: ['reports', 'price-changes', range.start.getTime(), range.end.getTime()],
    queryFn: () => repo.listPriceChangesInRange(range.start, range.end),
  });
  return {
    rows: q.data ? priceChangeRowsInRange(q.data) : [],
    isLoading: q.isLoading,
    error: (q.error as Error) ?? null,
  };
}

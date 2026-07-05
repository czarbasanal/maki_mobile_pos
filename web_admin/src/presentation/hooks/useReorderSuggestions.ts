import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useProducts } from './useProducts';
import { useSaleRepo } from '@/infrastructure/di/container';
import { reorderWindow } from '@/domain/reorder/reorderWindow';
import { unitsSoldByProduct } from '@/domain/reorder/unitsSoldByProduct';
import {
  computeReorderSuggestions,
  type ReorderParams,
  type ReorderSuggestion,
} from '@/domain/reorder/computeReorderSuggestions';

export const REORDER_SALES_CAP = 10_000;

export function useReorderSuggestions(params: ReorderParams, now: Date) {
  const saleRepo = useSaleRepo();
  const { data: products, isLoading: lp } = useProducts();

  const range = useMemo(
    () => reorderWindow(now, params.windowDays),
    [now, params.windowDays],
  );

  const salesQ = useQuery({
    queryKey: ['reorder', 'sales', range.start.getTime(), range.end.getTime()],
    queryFn: () =>
      saleRepo.list({ start: range.start, end: range.end, limit: REORDER_SALES_CAP }),
  });

  const suggestions = useMemo<ReorderSuggestion[]>(() => {
    if (!products || !salesQ.data) return [];
    return computeReorderSuggestions(products, unitsSoldByProduct(salesQ.data), params);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [products, salesQ.data, params.windowDays, params.coverDays]);

  return {
    suggestions,
    isLoading: lp || salesQ.isLoading,
    error: (salesQ.error as Error) ?? null,
    capped: (salesQ.data?.length ?? 0) >= REORDER_SALES_CAP,
  };
}

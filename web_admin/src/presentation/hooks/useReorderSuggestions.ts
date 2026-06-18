import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { endOfDay, startOfDay, subDays } from 'date-fns';
import { useProducts } from './useProducts';
import { useSaleRepo } from '@/infrastructure/di/container';
import { unitsSoldByProduct } from '@/domain/reorder/unitsSoldByProduct';
import {
  computeReorderSuggestions,
  type ReorderParams,
  type ReorderSuggestion,
} from '@/domain/reorder/computeReorderSuggestions';

const SALES_CAP = 2000;

export function useReorderSuggestions(params: ReorderParams, now: Date) {
  const saleRepo = useSaleRepo();
  const { data: products, isLoading: lp } = useProducts();

  const range = useMemo(
    () => ({
      start: startOfDay(subDays(now, params.windowDays - 1)),
      end: endOfDay(now),
    }),
    [now, params.windowDays],
  );

  const salesQ = useQuery({
    queryKey: ['reorder', 'sales', range.start.getTime(), range.end.getTime()],
    queryFn: () => saleRepo.list({ start: range.start, end: range.end, limit: SALES_CAP }),
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
    capped: (salesQ.data?.length ?? 0) >= SALES_CAP,
  };
}

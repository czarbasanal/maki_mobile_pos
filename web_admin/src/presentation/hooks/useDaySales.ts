import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { endOfDay, startOfDay } from 'date-fns';
import { useSaleRepo } from '@/infrastructure/di/container';
import type { Sale } from '@/domain/entities';

export interface DaySalesResult {
  sales: Sale[];
  isLoading: boolean;
  error: Error | null;
}

/**
 * Thin range query for a single day's sales — [00:00, 23:59:59.999] of
 * `date` — reusing the same SaleRepository.list() range contract as
 * useReportData.
 */
export function useDaySales(date: Date): DaySalesResult {
  const repo = useSaleRepo();
  const range = useMemo(() => ({ start: startOfDay(date), end: endOfDay(date) }), [date]);

  const query = useQuery({
    queryKey: ['sales', 'day', range.start.getTime(), range.end.getTime()],
    queryFn: () => repo.list({ start: range.start, end: range.end }),
  });

  return {
    sales: query.data ?? [],
    isLoading: query.isLoading,
    error: (query.error as Error) ?? null,
  };
}

import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { instantOf, shopWall } from '@/domain/time/shopTime';
import { useSaleRepo } from '@/infrastructure/di/container';
import type { Sale } from '@/domain/entities';

export interface DaySalesResult {
  sales: Sale[];
  isLoading: boolean;
  error: Error | null;
}

/**
 * Thin range query for a single SHOP day's sales — [00:00, 23:59:59.999]
 * PHT of `date`'s calendar day — reusing the same SaleRepository.list() range contract as
 * useReportData.
 */
export function useDaySales(date: Date): DaySalesResult {
  const repo = useSaleRepo();
  // The CALENDAR date the picker shows maps to that SHOP (PHT) day —
  // regardless of the viewer's timezone.
  const range = useMemo(() => {
    const y = date.getFullYear();
    const m = date.getMonth() + 1;
    const d = date.getDate();
    return {
      start: instantOf(shopWall(y, m, d)),
      end: instantOf(shopWall(y, m, d, 23, 59, 59, 999)),
    };
  }, [date]);

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

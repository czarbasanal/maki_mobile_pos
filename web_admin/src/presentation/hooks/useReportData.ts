import { useQuery } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import { summarizeSales, type SalesSummary } from '@/domain/sales/summarizeSales';
import {
  topSellingProducts,
  type ProductSalesData,
} from '@/domain/sales/topSellingProducts';
import { type Sale } from '@/domain/entities';
import type { DateRange } from '@/domain/reports/dateRange';

export const SALES_FETCH_CAP = 2000;

export interface ReportData {
  sales: Sale[];
  summary: SalesSummary;
  topProducts: ProductSalesData[];
  /** True when the fetch hit the cap, so figures may be partial. */
  capped: boolean;
  isLoading: boolean;
  error: Error | null;
}

export function useReportData(range: DateRange): ReportData {
  const repo = useSaleRepo();
  const query = useQuery({
    queryKey: ['reports', 'sales', range.start.getTime(), range.end.getTime()],
    queryFn: () =>
      repo.list({ start: range.start, end: range.end, limit: SALES_FETCH_CAP }),
  });

  const sales = query.data ?? [];
  return {
    sales,
    summary: summarizeSales(sales),
    topProducts: topSellingProducts(sales),
    capped: sales.length >= SALES_FETCH_CAP,
    isLoading: query.isLoading,
    error: (query.error as Error) ?? null,
  };
}

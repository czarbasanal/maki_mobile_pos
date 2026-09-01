// Prior business day's summary for the KPI delta chips (spec §5.1).
// Range is computed in SHOP time — not the browser's calendar.
import { useQuery } from '@tanstack/react-query';
import { summarizeSales, type SalesSummary } from '@/domain/sales/summarizeSales';
import { shopDateKey, shopEndOfDay, shopStartOfDay } from '@/domain/time/shopTime';
import { useSaleRepo } from '@/infrastructure/di/container';

const DAY_MS = 24 * 60 * 60 * 1000;

export function useYesterdaySales(): { summary: SalesSummary | null; isLoading: boolean } {
  const repo = useSaleRepo();
  const yesterday = new Date(Date.now() - DAY_MS);
  const { data, isLoading } = useQuery({
    queryKey: ['sales', 'yesterday', shopDateKey(yesterday)],
    queryFn: () => repo.list({ start: shopStartOfDay(yesterday), end: shopEndOfDay(yesterday) }),
  });
  return { summary: data ? summarizeSales(data) : null, isLoading };
}

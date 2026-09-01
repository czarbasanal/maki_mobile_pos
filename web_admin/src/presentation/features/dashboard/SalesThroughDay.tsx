import { useMemo } from 'react';
import { bucketSalesByHour, formatHourLabel, peakHour } from '@/domain/sales/hourlySales';
import type { Sale } from '@/domain/entities';
import type { SalesSummary } from '@/domain/sales/summarizeSales';
import { Card } from '@/presentation/components/ui/Card';
import { EmptyState } from '@/presentation/components/ui/EmptyState';
import { Skeleton } from '@/presentation/components/ui/Skeleton';
import { BarChart } from '@/presentation/components/ui/charts/BarChart';
import { SegmentedBar } from '@/presentation/components/ui/charts/SegmentedBar';

export function SalesThroughDay({
  sales,
  summary,
  canSeeCost,
  loading,
}: {
  sales: Sale[];
  summary: SalesSummary;
  canSeeCost: boolean;
  loading: boolean;
}) {
  const buckets = useMemo(() => bucketSalesByHour(sales), [sales]);
  const peak = peakHour(buckets);
  const highlight = peak == null ? undefined : buckets.findIndex((b) => b.hour === peak);
  const cogs = summary.totalCost;
  const profit = summary.totalProfit;

  return (
    <Card
      title="Sales through the day"
      subtitle={peak != null ? `Peak ${formatHourLabel(peak, true)}` : undefined}
    >
      {loading ? (
        <Skeleton height="110px" />
      ) : (
        <BarChart
          data={buckets.map((b) => ({ label: formatHourLabel(b.hour), value: b.count }))}
          highlight={highlight}
          empty={<EmptyState message="No sales yet today" />}
        />
      )}
      {canSeeCost && !loading && (cogs > 0 || profit > 0) && (
        <div className="mt-5 border-t border-line-2 pt-4">
          <div className="mb-2 flex items-center justify-between">
            <span className="text-micro-caps uppercase text-ink-3">Margin</span>
            {/* profitMargin is already a percentage (see summarizeSales.ts) — don't re-scale it. */}
            <span className="font-mono text-micro text-ink-2">{summary.profitMargin.toFixed(1)}% profit</span>
          </div>
          <SegmentedBar
            segments={[
              { label: 'COGS', value: cogs, color: 'surface-3' },
              { label: 'Profit', value: profit, color: 'accent' },
            ]}
          />
        </div>
      )}
    </Card>
  );
}

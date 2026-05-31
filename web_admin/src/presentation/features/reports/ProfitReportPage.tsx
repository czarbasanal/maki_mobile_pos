import { useEffect, useMemo, useState } from 'react';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import { useReportData } from '@/presentation/hooks/useReportData';
import { formatMoney } from '@/core/utils/money';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { SummaryCard } from '@/presentation/features/dashboard/SummaryCard';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

export function ProfitReportPage() {
  const [range, setRange] = useState<DateRange>(() => resolvePreset('last7'));
  const { summary, topProducts, isLoading, error } = useReportData(range);

  // Top products by PROFIT (the report's lens), not revenue.
  const byProfit = useMemo(
    () => [...topProducts].sort((a, b) => b.totalProfit - a.totalProfit),
    [topProducts],
  );

  useEffect(() => {
    document.title = 'Profit report · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Profit report
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Cost of goods, gross profit, and margin for the selected range.
          </p>
        </div>
        <DateRangePicker onChange={setRange} />
      </header>

      {error ? (
        <ErrorView title="Could not load profit" message={error.message} />
      ) : isLoading ? (
        <div className="h-32">
          <LoadingView label="Loading…" />
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2 lg:grid-cols-4">
            <SummaryCard title="Gross Sales" value={formatMoney(summary.grossAmount)} />
            <SummaryCard title="Total COGS" value={formatMoney(summary.totalCost)} />
            <SummaryCard
              title="Gross Profit"
              value={formatMoney(summary.totalProfit)}
              emphasized
            />
            <SummaryCard title="Margin" value={`${summary.profitMargin.toFixed(1)}%`} />
          </div>
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            <SummaryCard title="Service / Labor profit" value={formatMoney(summary.laborProfit)} />
          </div>

          <section className="rounded-lg border border-light-hairline bg-light-card p-tk-lg">
            <h2 className="mb-tk-md text-bodyMedium font-semibold text-light-text">
              Top products by profit
            </h2>
            {byProfit.length === 0 ? (
              <p className="text-bodySmall text-light-text-hint">No products sold in this range.</p>
            ) : (
              <table className="w-full text-bodySmall">
                <thead className="text-light-text-secondary">
                  <tr>
                    <th className="py-tk-xs text-left font-medium">Product</th>
                    <th className="py-tk-xs text-right font-medium">Qty</th>
                    <th className="py-tk-xs text-right font-medium">Revenue</th>
                    <th className="py-tk-xs text-right font-medium">Cost</th>
                    <th className="py-tk-xs text-right font-medium">Profit</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-light-hairline">
                  {byProfit.map((p) => (
                    <tr key={p.sku}>
                      <td className="py-tk-xs">{p.name}</td>
                      <td className="py-tk-xs text-right tabular-nums">{p.quantitySold}</td>
                      <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalRevenue)}</td>
                      <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalCost)}</td>
                      <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalProfit)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </section>
        </>
      )}
    </div>
  );
}

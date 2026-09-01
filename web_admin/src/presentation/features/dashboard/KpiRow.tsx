import { percentDelta } from '@/domain/reports/compare';
import type { SalesSummary } from '@/domain/sales/summarizeSales';
import { StatCard } from '@/presentation/components/ui/StatCard';

export interface KpiRowProps {
  summary: SalesSummary;
  yesterday: SalesSummary | null;
  canSeeCost: boolean;
  loading: boolean;
}

export function KpiRow({ summary, yesterday, canSeeCost, loading }: KpiRowProps) {
  const revenue = summary.netAmount + summary.laborRevenue + summary.feesRevenue;
  const count = summary.totalSalesCount;
  const avgOrder = count === 0 ? 0 : revenue / count;
  const yRevenue = yesterday ? yesterday.netAmount + yesterday.laborRevenue + yesterday.feesRevenue : 0;
  const yAvg = yesterday && yesterday.totalSalesCount > 0 ? yRevenue / yesterday.totalSalesCount : 0;
  const cogsShare = summary.grossAmount > 0 ? ((summary.totalCost / summary.grossAmount) * 100).toFixed(1) : null;
  // profitMargin is already a percentage (see summarizeSales.ts) — don't re-scale it.
  const margin = summary.profitMargin.toFixed(1);

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
      <StatCard label="Sales today" value={count} format="number" loading={loading}
        delta={yesterday ? percentDelta(count, yesterday.totalSalesCount) : null} note="vs prior business day" />
      <StatCard label="Gross Sales" value={summary.grossAmount} format="currency" loading={loading}
        delta={yesterday ? percentDelta(summary.grossAmount, yesterday.grossAmount) : null} note="vs prior business day" />
      {canSeeCost && (
        <StatCard label="Total COGS" value={summary.totalCost} format="currency" loading={loading}
          chip={cogsShare ? { label: `${cogsShare}% of gross`, tone: 'neutral' } : undefined} />
      )}
      {canSeeCost && (
        <StatCard label="Gross profit" value={summary.totalProfit} format="currency" loading={loading}
          chip={{ label: `${margin}% margin`, tone: 'neutral' }} />
      )}
      <StatCard label="Avg order" value={avgOrder} format="currency" loading={loading}
        delta={yesterday ? percentDelta(avgOrder, yAvg) : null} note="vs prior business day" />
    </div>
  );
}

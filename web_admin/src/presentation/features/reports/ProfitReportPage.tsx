// Profit report (reports guide §1): four cards in ONE row, Gross profit
// (net parts − COGS; labor is its own track and never in gross) leading with
// its margin as the note; margin is a column with a MiniBar,
// coloured by band (≥50% pos · 25–49% text-2 · <25% neg). The table lists
// every product in range by profit so its columns reconcile with the KPIs.
import { useEffect, useMemo } from 'react';
import { ArrowTrendingUpIcon } from '@heroicons/react/24/outline';
import { useReportData } from '@/presentation/hooks/useReportData';
import { deriveReportFigures, type ProductFigures } from '@/domain/reports/reportFigures';
import { toCsv, downloadCsv } from '@/core/utils/csv';
import { csvSku } from '@/domain/products/sku';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { marginToneClass } from '@/domain/products/margin';
import { StatCard } from '@/presentation/components/ui/StatCard';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { MiniBar } from '@/presentation/components/ui/MiniBar';
import { ErrorState } from '@/presentation/components/ui/ErrorState';
import { ReportHeader } from './ReportHeader';
import { ReportTableCard } from './ReportTableCard';
import { EmptyRangeState } from '@/presentation/components/ui/EmptyRangeState';
import { useReportRange } from '@/presentation/hooks/useReportRange';
import { csvFileName, pctLabel } from '@/core/utils/reportFormat';

/** The app-wide margin bands (domain/products/margin.ts) as text class + the matching fill var. */
function marginBand(margin: number): { text: string; fill: string } {
  const text = marginToneClass(Math.round(margin * 100));
  const fill = text === 'text-pos' ? 'var(--pos)' : text === 'text-neg' ? 'var(--neg)' : 'var(--text-2)';
  return { text, fill };
}

export function ProfitReportPage() {
  const range = useReportRange('last7');
  const { sales, isLoading, error, refetch } = useReportData(range.effectiveRange);
  const f = useMemo(() => deriveReportFigures(sales), [sales]);

  useEffect(() => {
    document.title = 'Profit report · MAKI POS Admin';
  }, []);

  const exportCsv = () =>
    downloadCsv(
      csvFileName('profit', range.effectiveRange),
      toCsv(
        ['Product', 'SKU', 'Qty', 'Revenue', 'Cost', 'Profit', 'Margin %'],
        f.products.map((p) => [
          p.name, csvSku(p.sku), p.qty, p.revenue.toFixed(2), p.cost.toFixed(2), p.profit.toFixed(2),
          p.margin === null ? '' : (p.margin * 100).toFixed(1),
        ]),
      ),
    );

  const columns: Array<Column<ProductFigures>> = [
    { key: 'name', header: 'Product', render: (p) => <span className="text-ctl-md font-medium text-ink">{p.name}</span> },
    { key: 'qty', header: 'Qty', align: 'right', width: '62px', mono: true, render: (p) => <span className="text-[12px] text-ink-2">{p.qty}</span> },
    { key: 'rev', header: 'Revenue', align: 'right', width: '112px', mono: true, render: (p) => <span className="text-ctl-md text-ink-2">{formatMoney(p.revenue)}</span> },
    { key: 'cost', header: 'Cost', align: 'right', width: '112px', mono: true, render: (p) => <span className="text-ctl-md text-ink-2">{formatMoney(p.cost)}</span> },
    { key: 'profit', header: 'Profit', align: 'right', width: '112px', mono: true, render: (p) => <span className="text-[13px] font-semibold text-ink">{formatMoney(p.profit)}</span> },
    {
      key: 'margin', header: 'Margin', align: 'right', width: '86px',
      render: (p) => {
        if (p.margin === null) return <span className="font-mono text-[12px] text-ink-3">—</span>;
        const band = marginBand(p.margin);
        return (
          <div className="flex items-center justify-end gap-2">
            <MiniBar pct={Math.max(0, p.margin) * 100} color={band.fill} width="34px" />
            <span className={cn('w-[34px] text-right font-mono text-[12px] font-semibold', band.text)}>{pctLabel(p.margin)}</span>
          </div>
        );
      },
    },
  ];

  if (error) return <ErrorState message="Could not load profit." onRetry={refetch} />;

  return (
    <div className="flex flex-col gap-3">
      <ReportHeader range={range} onExport={exportCsv} exportDisabled={f.products.length === 0} />

      <div className="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] gap-3">
        <StatCard lead label="Gross profit" value={f.profit} format="currency" loading={isLoading}
          note={`${pctLabel(f.margin, 1)} margin`} />
        <StatCard label="Gross sales" value={f.gross} format="currency" loading={isLoading}
          note={f.discounts > 0 ? `${formatMoney(f.net)} after discounts` : range.rangeNote} />
        <StatCard label="Total COGS" value={f.cogs} format="currency" loading={isLoading}
          note={f.net > 0 ? `${pctLabel(f.cogs / f.net, 1)} of sales` : '—'} />
        <StatCard label="Service / labor profit" value={f.labor} format="currency" note="no cost of goods · not in gross" loading={isLoading} />
      </div>

      <ReportTableCard title="Top products by profit" note={range.rangeNote}>
        <DataTable
          columns={columns}
          rows={f.products}
          rowKey={(p) => p.productId}
          loading={isLoading}
          minWidth="820px"
          empty={
            <EmptyRangeState
              icon={<ArrowTrendingUpIcon className="h-[22px] w-[22px] text-ink-3" />}
              title="No sales in this range"
              description={`Nothing was sold ${range.rangeNote}, so there is no cost of goods to report.`}
              onWiden={range.widen}
              widenLabel={range.widenLabel}
            />
          }
        />
      </ReportTableCard>
    </div>
  );
}

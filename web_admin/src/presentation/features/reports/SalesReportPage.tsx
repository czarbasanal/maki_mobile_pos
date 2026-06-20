import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ChartBarIcon, ArrowLeftIcon } from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import { useReportData } from '@/presentation/hooks/useReportData';
import { salesToCsv, downloadCsv } from '@/core/utils/csv';
import { formatMoney } from '@/core/utils/money';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { SummaryCard } from '@/presentation/features/dashboard/SummaryCard';
import { SalesTable } from './SalesTable';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

const fileStamp = (d: Date) =>
  `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(
    d.getDate(),
  ).padStart(2, '0')}`;

export function SalesReportPage() {
  const [range, setRange] = useState<DateRange>(() => resolvePreset('last7'));
  const { sales, summary, topProducts, capped, isLoading, error } = useReportData(range);

  useEffect(() => {
    document.title = 'Sales report · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <Link
            to={RoutePaths.reports}
            className="mb-tk-xs inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
          >
            <ArrowLeftIcon className="h-3.5 w-3.5" /> Reports
          </Link>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Sales report
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Sales and payment breakdown for the selected range.
          </p>
        </div>
        <DateRangePicker onChange={setRange} />
      </header>

      {error ? (
        <ErrorView title="Could not load sales" message={error.message} />
      ) : isLoading ? (
        <div className="h-32">
          <LoadingView label="Loading sales…" />
        </div>
      ) : (
        <>
          {capped ? (
            <p className="rounded-md border border-warning bg-warning-light px-tk-md py-tk-sm text-bodySmall text-warning-dark">
              Showing the most recent 2,000 sales — narrow the date range for exact totals.
            </p>
          ) : null}

          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2 lg:grid-cols-4">
            <SummaryCard title="Gross Sales" value={formatMoney(summary.grossAmount)} emphasized />
            <SummaryCard title="Net" value={formatMoney(summary.netAmount)} />
            <SummaryCard title="Avg order" value={formatMoney(summary.averageSaleAmount)} />
            <SummaryCard title="Sales count" value={String(summary.totalSalesCount)} />
          </div>

          <div className="grid grid-cols-1 gap-tk-lg lg:grid-cols-3">
            <Panel title="By payment method">
              <dl className="space-y-tk-sm text-bodySmall">
                {(['cash', 'gcash', 'maya', 'salmon'] as const).map((m) => (
                  <div key={m} className="flex justify-between">
                    <dt className="capitalize text-light-text-secondary">{m}</dt>
                    <dd className="tabular-nums">{formatMoney(summary.byPaymentMethod[m])}</dd>
                  </div>
                ))}
                <div className="flex justify-between border-t border-light-hairline pt-tk-sm">
                  <dt className="text-light-text-secondary">Service / Labor</dt>
                  <dd className="tabular-nums">{formatMoney(summary.laborRevenue)}</dd>
                </div>
              </dl>
            </Panel>
            <Panel title="Top products" className="lg:col-span-2">
              <TopProducts rows={topProducts} />
            </Panel>
          </div>

          <section className="space-y-tk-md">
            <div className="flex items-center justify-between">
              <h2 className="text-bodyMedium font-semibold text-light-text">
                Sales ({sales.length})
              </h2>
              <button
                type="button"
                disabled={sales.length === 0}
                onClick={() =>
                  downloadCsv(
                    `sales-${fileStamp(range.start)}-${fileStamp(range.end)}.csv`,
                    salesToCsv(sales),
                  )
                }
                className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-50"
              >
                <ChartBarIcon className="h-4 w-4" />
                Download CSV
              </button>
            </div>
            <SalesTable sales={sales} />
          </section>
        </>
      )}
    </div>
  );
}

function TopProducts({
  rows,
}: {
  rows: {
    sku: string;
    name: string;
    quantitySold: number;
    totalRevenue: number;
    totalProfit: number;
  }[];
}) {
  if (rows.length === 0) {
    return <p className="text-bodySmall text-light-text-hint">No products sold in this range.</p>;
  }
  return (
    <table className="w-full text-bodySmall">
      <thead className="text-light-text-secondary">
        <tr>
          <th className="py-tk-xs text-left font-medium">Product</th>
          <th className="py-tk-xs text-right font-medium">Qty</th>
          <th className="py-tk-xs text-right font-medium">Revenue</th>
          <th className="py-tk-xs text-right font-medium">Profit</th>
        </tr>
      </thead>
      <tbody className="divide-y divide-light-hairline">
        {rows.map((p) => (
          <tr key={p.sku}>
            <td className="py-tk-xs">{p.name}</td>
            <td className="py-tk-xs text-right tabular-nums">{p.quantitySold}</td>
            <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalRevenue)}</td>
            <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalProfit)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function Panel({
  title,
  className,
  children,
}: {
  title: string;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <section
      className={`rounded-lg border border-light-hairline bg-light-card p-tk-lg ${className ?? ''}`}
    >
      <h2 className="mb-tk-md text-bodyMedium font-semibold text-light-text">{title}</h2>
      {children}
    </section>
  );
}

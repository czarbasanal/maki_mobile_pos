// /admin/ — read-only dashboard. Vercel-airy: page header on white, four
// summary tiles in a grid, recent sales + inventory side-by-side.

import { useEffect, useMemo } from 'react';
import {
  ArrowTrendingUpIcon,
  BanknotesIcon,
  ChartBarIcon,
  ReceiptPercentIcon,
} from '@heroicons/react/24/outline';
import { useTodaysSales } from '@/presentation/hooks/useTodaysSales';
import {
  saleGrandTotal,
  saleIsVoided,
  saleTotalProfit,
  type Sale,
} from '@/domain/entities';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { SummaryCard } from './SummaryCard';
import { RecentSales } from './RecentSales';
import { InventoryStatus } from './InventoryStatus';
import { formatMoney } from '@/core/utils/money';

interface SalesSummary {
  count: number;
  revenue: number;
  profit: number;
  averageOrder: number;
}

function summarize(sales: Sale[]): SalesSummary {
  // Voided sales don't count toward revenue/profit/avg, but they're shown
  // in the recent sales list with the "VOID" pill — same as Flutter.
  const completed = sales.filter((s) => !saleIsVoided(s));
  let revenue = 0;
  let profit = 0;
  for (const s of completed) {
    revenue += saleGrandTotal(s);
    profit += saleTotalProfit(s);
  }
  const count = completed.length;
  return {
    count,
    revenue,
    profit,
    averageOrder: count === 0 ? 0 : revenue / count,
  };
}

export function DashboardPage() {
  const { data: sales, isLoading, error } = useTodaysSales();
  const summary = useMemo(() => summarize(sales ?? []), [sales]);

  useEffect(() => {
    document.title = 'Dashboard · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Dashboard
        </h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Live snapshot of today's activity.
        </p>
      </header>

      {error ? (
        <ErrorView title="Could not load sales" message={error.message} />
      ) : isLoading || !sales ? (
        <div className="h-32">
          <LoadingView label="Loading today's sales…" />
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2 lg:grid-cols-4">
          <SummaryCard
            title="Sales today"
            value={String(summary.count)}
            icon={ReceiptPercentIcon}
            tone="blue"
          />
          <SummaryCard
            title="Revenue"
            value={formatMoney(summary.revenue)}
            icon={BanknotesIcon}
            tone="yellow"
            emphasized
          />
          <SummaryCard
            title="Gross profit"
            value={formatMoney(summary.profit)}
            icon={ArrowTrendingUpIcon}
            tone="green"
          />
          <SummaryCard
            title="Avg order"
            value={formatMoney(summary.averageOrder)}
            icon={ChartBarIcon}
            tone="violet"
          />
        </div>
      )}

      <div className="grid grid-cols-1 gap-tk-lg lg:grid-cols-3">
        <Panel title="Recent sales" className="lg:col-span-2">
          {error ? (
            <ErrorView message={error.message} />
          ) : isLoading || !sales ? (
            <LoadingView label="Loading sales…" />
          ) : (
            <RecentSales sales={sales} limit={8} />
          )}
        </Panel>
        <Panel title="Inventory status">
          <InventoryStatus />
        </Panel>
      </div>
    </div>
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

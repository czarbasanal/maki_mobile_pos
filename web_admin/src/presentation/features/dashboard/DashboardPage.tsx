// Read-only dashboard. Vercel-airy: page header on white, five summary tiles
// in a grid, recent sales + inventory side-by-side.

import { useEffect, useMemo } from 'react';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useAuthStore } from '@/presentation/stores/authStore';
import { Link } from 'react-router-dom';
import {
  ArrowTrendingUpIcon,
  BanknotesIcon,
  ChartBarIcon,
  CubeIcon,
  ReceiptPercentIcon,
} from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';
import { useTodaysSales } from '@/presentation/hooks/useTodaysSales';
import { summarizeSales } from '@/domain/sales/summarizeSales';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { SummaryCard } from './SummaryCard';
import { RecentSales } from './RecentSales';
import { InventoryStatus } from './InventoryStatus';
import { formatMoney } from '@/core/utils/money';

export function DashboardPage() {
  const { data: sales, isLoading, error } = useTodaysSales();
  const summary = useMemo(() => summarizeSales(sales ?? []), [sales]);
  const revenue = summary.netAmount + summary.laborRevenue + summary.feesRevenue;
  const profit = summary.totalProfit;
  const user = useAuthStore((s) => s.user);
  const canSeeCost =
    !!user && hasPermission(user.role, Permission.viewProductCost);
  const count = summary.totalSalesCount;
  const averageOrder = count === 0 ? 0 : revenue / count;

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
        <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2 lg:grid-cols-5">
          <SummaryCard
            title="Sales today"
            value={String(count)}
            icon={ReceiptPercentIcon}
            tone="blue"
          />
          <SummaryCard
            title="Gross Sales"
            value={formatMoney(summary.grossAmount)}
            icon={BanknotesIcon}
            tone="yellow"
          />
          {/* COGS and profit derive from product costs — admin-only, matching
              the phone dashboard, which hides this whole block from other
              roles. Sales/avg-order stay: they're register figures. */}
          {canSeeCost ? (
            <SummaryCard
              title="Total COGS"
              value={formatMoney(summary.totalCost)}
              icon={CubeIcon}
              tone="orange"
            />
          ) : null}
          {canSeeCost ? (
            <SummaryCard
              title="Gross profit"
              value={formatMoney(profit)}
              icon={ArrowTrendingUpIcon}
              tone="green"
            />
          ) : null}
          <SummaryCard
            title="Avg order"
            value={formatMoney(averageOrder)}
            icon={ChartBarIcon}
            tone="violet"
          />
        </div>
      )}

      <div className="grid grid-cols-1 gap-tk-lg lg:grid-cols-3">
        <Panel
          title="Recent sales"
          className="lg:col-span-2"
          action={
            <Link
              to={RoutePaths.daySales}
              className="text-bodySmall font-medium text-light-text-secondary hover:text-light-text hover:underline"
            >
              View all →
            </Link>
          }
        >
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
  action,
  children,
}: {
  title: string;
  className?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section
      className={`rounded-lg border border-light-hairline bg-light-card p-tk-lg ${className ?? ''}`}
    >
      <div className="mb-tk-md flex items-center justify-between">
        <h2 className="text-bodyMedium font-semibold text-light-text">{title}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}

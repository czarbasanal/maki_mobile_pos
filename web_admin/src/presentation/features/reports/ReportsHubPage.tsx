// Reports index (reports guide §1): four nav cards, each carrying two live
// figures for the active range. One scoped fetch feeds every card, so the
// profit figure can never sit above a smaller gross figure again.
import { useEffect, useMemo } from 'react';
import { useLocation } from 'react-router-dom';
import { ChartBarIcon, ArrowTrendingUpIcon, WrenchIcon, TagIcon } from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useReportData } from '@/presentation/hooks/useReportData';
import { usePriceChangeReport } from '@/presentation/hooks/usePriceChangeReport';
import { deriveReportFigures } from '@/domain/reports/reportFigures';
import { priceChangeCounts } from '@/domain/products/priceChangeReason';
import { formatMoney } from '@/core/utils/money';
import { ErrorState } from '@/presentation/components/ui/ErrorState';
import { ReportHeader } from './ReportHeader';
import { ReportNavCard, type NavFigure } from './ReportNavCard';
import { useReportRange } from './useReportRange';
import { pctLabel } from './reportFormat';

const ICON = 'h-[17px] w-[17px]';

export function ReportsHubPage() {
  const user = useAuthStore((st) => st.user);
  const can = (p: Permission) => !!user && hasPermission(user.role, p);
  const dailyOnly = can(Permission.viewDailySalesOnly);
  const range = useReportRange('last7', dailyOnly);
  // The cards hand the selected range to the report they open.
  const { search } = useLocation();

  const salesData = useReportData(range.effectiveRange);
  const prices = usePriceChangeReport(range.effectiveRange, { enabled: can(Permission.viewProductCost) });
  const f = useMemo(() => deriveReportFigures(salesData.sales), [salesData.sales]);
  const pc = useMemo(() => priceChangeCounts(prices.rows), [prices.rows]);

  useEffect(() => {
    document.title = 'Reports · MAKI POS Admin';
  }, []);

  if (salesData.error || prices.error) {
    return (
      <ErrorState
        message="Could not load reports."
        onRetry={() => {
          salesData.refetch();
          prices.refetch();
        }}
      />
    );
  }

  // Each card carries the permission its route is guarded by, so the hub can
  // never surface a report the guard would bounce (mobile-parity filtering).
  const cards = [
    {
      to: RoutePaths.salesReport,
      title: 'Sales report',
      description: 'Sales, payment breakdown, top products, and a downloadable sales list.',
      icon: <ChartBarIcon className={ICON} />,
      permission: Permission.viewSalesReports,
      loading: salesData.isLoading,
      figures: [
        { label: 'Gross', value: formatMoney(f.gross) },
        { label: 'Sales', value: String(f.count) },
      ] satisfies [NavFigure, NavFigure],
    },
    {
      to: RoutePaths.profitReport,
      title: 'Profit report',
      description: 'Cost of goods, gross profit, margin, and top products by profit.',
      icon: <ArrowTrendingUpIcon className={ICON} />,
      permission: Permission.viewProfitReports,
      loading: salesData.isLoading,
      figures: [
        { label: 'Profit', value: formatMoney(f.profit), positive: true },
        { label: 'Margin', value: pctLabel(f.margin, 1) },
      ] satisfies [NavFigure, NavFigure],
    },
    {
      to: RoutePaths.laborReport,
      title: 'Labor report',
      description: 'Service revenue and a per-mechanic breakdown of labor.',
      icon: <WrenchIcon className={ICON} />,
      permission: Permission.viewSalesReports,
      loading: salesData.isLoading,
      figures: [
        { label: 'Labor', value: formatMoney(f.labor) },
        { label: 'Jobs', value: String(f.laborReport.serviceSaleCount) },
      ] satisfies [NavFigure, NavFigure],
    },
    {
      to: RoutePaths.priceChangeReport,
      title: 'Price changes',
      description: 'Price/cost changes across products over a date range.',
      icon: <TagIcon className={ICON} />,
      permission: Permission.viewProductCost,
      loading: prices.isLoading,
      figures: [
        { label: 'Logged', value: String(pc.logged) },
        { label: 'Repriced', value: String(pc.increases + pc.cuts) },
      ] satisfies [NavFigure, NavFigure],
    },
  ];

  return (
    <div className="flex flex-col gap-3">
      <ReportHeader
        range={range}
        back={false}
        lock={dailyOnly ? "Showing today's figures only. Contact an admin for historical reports." : undefined}
      />
      <div className="grid grid-cols-[repeat(auto-fit,minmax(300px,1fr))] gap-3">
        {cards
          .filter((c) => can(c.permission))
          .map((c) => (
            <ReportNavCard
              key={c.to}
              to={{ pathname: c.to, search }}
              icon={c.icon}
              title={c.title}
              description={c.description}
              figures={c.figures}
              rangeNote={range.rangeNote}
              loading={c.loading}
            />
          ))}
      </div>
    </div>
  );
}

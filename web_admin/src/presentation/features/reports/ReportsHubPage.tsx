import { useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ChartBarIcon, ArrowTrendingUpIcon, WrenchIcon, TagIcon } from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';

// Each tile carries the permission its route is guarded by, so the hub can
// never surface a report the guard would bounce (mobile-parity filtering).
const cards = [
  {
    to: RoutePaths.salesReport,
    title: 'Sales report',
    description: 'Sales, payment breakdown, top products, and a downloadable sales list.',
    icon: ChartBarIcon,
    permission: Permission.viewSalesReports,
  },
  {
    to: RoutePaths.profitReport,
    title: 'Profit report',
    description: 'Cost of goods, gross profit, margin, and top products by profit.',
    icon: ArrowTrendingUpIcon,
    permission: Permission.viewProfitReports,
  },
  {
    to: RoutePaths.laborReport,
    title: 'Labor report',
    description: 'Service revenue and a per-mechanic breakdown of labor.',
    icon: WrenchIcon,
    permission: Permission.viewSalesReports,
  },
  {
    to: RoutePaths.priceChangeReport,
    title: 'Price changes',
    description: 'Price/cost changes across products over a date range.',
    icon: TagIcon,
    permission: Permission.viewProductCost,
  },
];

export function ReportsHubPage() {
  const user = useAuthStore((st) => st.user);
  const visible = cards.filter((c) => !!user && hasPermission(user.role, c.permission));

  useEffect(() => {
    document.title = 'Reports · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Reports</h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Sales and profit over any date range.
        </p>
      </header>
      <div className="grid grid-cols-1 gap-tk-lg sm:grid-cols-2">
        {visible.map((c) => (
          <Link
            key={c.to}
            to={c.to}
            className="group rounded-lg border border-light-hairline bg-light-card p-tk-lg transition-colors hover:border-light-text"
          >
            <c.icon className="h-6 w-6 text-light-text-secondary" />
            <h2 className="mt-tk-md text-bodyMedium font-semibold text-light-text">{c.title}</h2>
            <p className="mt-tk-xs text-bodySmall text-light-text-secondary">{c.description}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}

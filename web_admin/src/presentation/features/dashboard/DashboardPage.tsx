// Read-only dashboard, recomposed on the shared ui component library. The
// AppShell header (route handle) owns the page title — this renders no
// header of its own.
import { useEffect, useMemo } from 'react';
import { summarizeSales } from '@/domain/sales/summarizeSales';
import { summarizeInventory } from '@/domain/products/inventoryStatus';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useTodaysSales } from '@/presentation/hooks/useTodaysSales';
import { useYesterdaySales } from '@/presentation/hooks/useYesterdaySales';
import { useProducts } from '@/presentation/hooks/useProducts';
import { canAccess } from '@/presentation/router/routeGuards';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ErrorState } from '@/presentation/components/ui/ErrorState';
import { KpiRow } from './KpiRow';
import { SalesThroughDay } from './SalesThroughDay';
import { InventoryStatusCard } from './InventoryStatusCard';
import { NeedsAttentionCard } from './NeedsAttentionCard';
import { RecentSalesTable } from './RecentSalesTable';

export function DashboardPage() {
  const user = useAuthStore((s) => s.user);
  const { data: sales, isLoading, error } = useTodaysSales();
  const { summary: yesterday } = useYesterdaySales();
  const { data: products } = useProducts();

  const summary = useMemo(() => summarizeSales(sales ?? []), [sales]);
  const inventory = useMemo(() => summarizeInventory(products ?? []), [products]);
  const canSeeCost = user != null && hasPermission(user.role, Permission.viewProductCost);
  const canApproveVoids = user != null && canAccess(RoutePaths.voidRequests, user);

  useEffect(() => {
    document.title = 'Dashboard · MAKI POS Admin';
  }, []);

  if (error) {
    return <ErrorState message="Couldn't load today's sales." onRetry={() => window.location.reload()} />;
  }

  return (
    <div className="grid gap-4">
      <KpiRow summary={summary} yesterday={yesterday} canSeeCost={canSeeCost} loading={isLoading} />
      <div className="grid gap-4 lg:grid-cols-[1.6fr_1fr]">
        <SalesThroughDay sales={sales ?? []} summary={summary} canSeeCost={canSeeCost} loading={isLoading} />
        <div className="grid content-start gap-4">
          <InventoryStatusCard />
          <NeedsAttentionCard inventory={inventory} canApproveVoids={canApproveVoids} />
        </div>
      </div>
      <RecentSalesTable sales={sales ?? []} loading={isLoading} />
    </div>
  );
}

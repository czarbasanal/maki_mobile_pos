import { Link } from 'react-router-dom';
import type { InventorySummary } from '@/domain/products/inventoryStatus';
import { useVoidRequests } from '@/presentation/hooks/useVoidRequests';
import { RoutePaths } from '@/presentation/router/routePaths';
import { Card } from '@/presentation/components/ui/Card';
import { EmptyState } from '@/presentation/components/ui/EmptyState';
import { Button } from '@/presentation/components/ui/Button';

function AttentionRow({ label, detail, action, to }: { label: string; detail: string; action: string; to: string }) {
  return (
    <li className="flex items-center justify-between gap-3 py-2.5">
      <div className="min-w-0">
        <p className="text-cell font-medium text-ink">{label}</p>
        <p className="text-micro text-ink-3">{detail}</p>
      </div>
      <Link to={to} className="shrink-0"><Button size="sm">{action}</Button></Link>
    </li>
  );
}

function NeedsAttentionBody({ inventory, pendingVoids }: { inventory: InventorySummary; pendingVoids: number }) {
  const allClear = inventory.outOfStock === 0 && inventory.lowStock === 0 && pendingVoids === 0;
  return (
    <Card title="Needs attention">
      <ul className="divide-y divide-line-2">
        {inventory.outOfStock > 0 && (
          <AttentionRow label="Out of stock" detail={`${inventory.outOfStock} SKUs unavailable at register`} action="Reorder" to={RoutePaths.inventory} />
        )}
        {inventory.lowStock > 0 && (
          <AttentionRow label="Low stock" detail={`${inventory.lowStock} SKUs below reorder point`} action="Review" to={RoutePaths.inventory} />
        )}
        {pendingVoids > 0 && (
          <AttentionRow
            label="Void requests"
            detail={`${pendingVoids} pending manager approval`}
            action="Approve"
            to={RoutePaths.voidRequests}
          />
        )}
      </ul>
      {allClear && <EmptyState message="All clear — nothing needs attention" />}
    </Card>
  );
}

// Split out so useVoidRequests only ever mounts for a user who may approve —
// the hook (and its Firestore subscription) never runs for a cashier.
function AdminNeedsAttention({ inventory }: { inventory: InventorySummary }) {
  const { pending } = useVoidRequests();
  return <NeedsAttentionBody inventory={inventory} pendingVoids={pending.length} />;
}

export function NeedsAttentionCard({ inventory, canApproveVoids }: { inventory: InventorySummary; canApproveVoids: boolean }) {
  if (canApproveVoids) return <AdminNeedsAttention inventory={inventory} />;
  return <NeedsAttentionBody inventory={inventory} pendingVoids={0} />;
}

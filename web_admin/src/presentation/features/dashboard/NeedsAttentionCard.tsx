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

function VoidRequestsRow() {
  const { pending } = useVoidRequests();
  if (pending.length === 0) return null;
  return (
    <AttentionRow
      label="Void requests"
      detail={`${pending.length} pending manager approval`}
      action="Approve"
      to={RoutePaths.voidRequests}
    />
  );
}

export function NeedsAttentionCard({ inventory, canApproveVoids }: { inventory: InventorySummary; canApproveVoids: boolean }) {
  const allClear = inventory.outOfStock === 0 && inventory.lowStock === 0 && !canApproveVoids;
  return (
    <Card title="Needs attention">
      <ul className="divide-y divide-line-2">
        {inventory.outOfStock > 0 && (
          <AttentionRow label="Out of stock" detail={`${inventory.outOfStock} SKUs unavailable at register`} action="Reorder" to={RoutePaths.inventory} />
        )}
        {inventory.lowStock > 0 && (
          <AttentionRow label="Low stock" detail={`${inventory.lowStock} SKUs below reorder point`} action="Review" to={RoutePaths.inventory} />
        )}
        {canApproveVoids && <VoidRequestsRow />}
      </ul>
      {allClear && <EmptyState message="All clear — nothing needs attention" />}
    </Card>
  );
}

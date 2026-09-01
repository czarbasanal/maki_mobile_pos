import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { sharePercent, summarizeInventory } from '@/domain/products/inventoryStatus';
import { useProducts } from '@/presentation/hooks/useProducts';
import { RoutePaths } from '@/presentation/router/routePaths';
import { Card } from '@/presentation/components/ui/Card';
import { Skeleton } from '@/presentation/components/ui/Skeleton';
import { SegmentedBar, type Segment } from '@/presentation/components/ui/charts/SegmentedBar';

const ROWS: Array<{ key: 'inStock' | 'lowStock' | 'outOfStock'; label: string; color: Segment['color']; dot: string }> = [
  { key: 'inStock', label: 'In stock', color: 'pos', dot: 'bg-pos' },
  { key: 'lowStock', label: 'Low stock', color: 'accent', dot: 'bg-accent' },
  { key: 'outOfStock', label: 'Out of stock', color: 'neg', dot: 'bg-neg' },
];

export function InventoryStatusCard() {
  const { data: products, isLoading } = useProducts();
  const summary = useMemo(() => summarizeInventory(products ?? []), [products]);

  return (
    <Card
      title="Inventory status"
      headerAction={<Link to={RoutePaths.inventory} className="text-ctl-sm font-medium text-ink-2 hover:text-ink">View all</Link>}
    >
      {isLoading ? (
        <div className="space-y-3"><Skeleton height="18px" /><Skeleton height="10px" /><Skeleton height="54px" /></div>
      ) : (
        <>
          <div className="mb-3 flex items-baseline gap-1.5">
            <span className="tnum font-mono text-inv-figure text-ink">{summary.total.toLocaleString('en-PH')}</span>
            <span className="text-micro text-ink-3">active SKUs</span>
          </div>
          <SegmentedBar segments={ROWS.map((r) => ({ label: r.label, value: summary[r.key], color: r.color }))} />
          <ul className="mt-3 space-y-2">
            {ROWS.map((row) => (
              <li key={row.key} className="flex items-center justify-between text-cell">
                <span className="flex items-center gap-2 text-ink-2">
                  <span aria-hidden className={`h-1.5 w-1.5 rounded-full ${row.dot}`} />
                  {row.label}
                </span>
                <span className="font-mono text-ink">
                  {summary[row.key].toLocaleString('en-PH')}
                  <span className="ml-1.5 text-ink-3">{sharePercent(summary[row.key], summary.total).toFixed(1)}%</span>
                </span>
              </li>
            ))}
          </ul>
        </>
      )}
    </Card>
  );
}

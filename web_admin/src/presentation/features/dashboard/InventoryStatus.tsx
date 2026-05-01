import { useMemo, type ComponentType, type SVGProps } from 'react';
import {
  CheckCircleIcon,
  CubeIcon,
  ExclamationTriangleIcon,
  XCircleIcon,
} from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import { getStockStatus, StockStatus } from '@/domain/entities';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { toneBadgeClasses, type Tone } from '@/core/theme/tones';
import { cn } from '@/core/utils/cn';

export function InventoryStatus() {
  const { data: products, isLoading, error } = useProducts();

  const summary = useMemo(() => {
    if (!products) return null;
    let inStock = 0;
    let lowStock = 0;
    let outOfStock = 0;
    for (const p of products) {
      if (!p.isActive) continue;
      const s = getStockStatus(p);
      if (s === StockStatus.inStock) inStock += 1;
      else if (s === StockStatus.lowStock) lowStock += 1;
      else outOfStock += 1;
    }
    return { total: inStock + lowStock + outOfStock, inStock, lowStock, outOfStock };
  }, [products]);

  if (error) return <ErrorView message={error.message} />;
  if (isLoading || !summary) return <LoadingView label="Loading inventory…" />;

  return (
    <ul className="divide-y divide-light-hairline">
      <Row label="Total" value={summary.total} icon={CubeIcon} tone="violet" />
      <Row label="In stock" value={summary.inStock} icon={CheckCircleIcon} tone="green" />
      <Row label="Low stock" value={summary.lowStock} icon={ExclamationTriangleIcon} tone="orange" />
      <Row label="Out of stock" value={summary.outOfStock} icon={XCircleIcon} tone="red" />
    </ul>
  );
}

function Row({
  label,
  value,
  icon: Icon,
  tone,
}: {
  label: string;
  value: number;
  icon: ComponentType<SVGProps<SVGSVGElement>>;
  tone: Tone;
}) {
  return (
    <li className="flex items-center gap-tk-sm py-tk-sm">
      <span
        className={cn(
          'grid h-6 w-6 shrink-0 place-items-center rounded-md',
          toneBadgeClasses[tone],
        )}
      >
        <Icon className="h-3.5 w-3.5" />
      </span>
      <span className="flex-1 text-bodySmall text-light-text-secondary">{label}</span>
      <span className="text-bodyMedium font-semibold tabular-nums text-light-text">{value}</span>
    </li>
  );
}

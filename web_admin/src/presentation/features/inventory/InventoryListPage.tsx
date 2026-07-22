import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { EyeIcon, EyeSlashIcon, MagnifyingGlassIcon, PlusIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import { RoutePaths } from '@/presentation/router/routePaths';
import { getStockStatus, StockStatus } from '@/domain/entities';
import { filterProducts, type ProductFilter } from '@/domain/products/filterProducts';
import { stockTotals } from '@/domain/products/stockTotals';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';

const STOCK_LABEL: Record<StockStatus, string> = {
  [StockStatus.inStock]: 'In stock',
  [StockStatus.lowStock]: 'Low stock',
  [StockStatus.outOfStock]: 'Out of stock',
};
const STOCK_BADGE: Record<StockStatus, string> = {
  [StockStatus.inStock]: 'bg-green-50 text-green-700',
  [StockStatus.lowStock]: 'bg-orange-50 text-orange-700',
  [StockStatus.outOfStock]: 'bg-red-50 text-red-700',
};

export function InventoryListPage() {
  useEffect(() => {
    document.title = 'Inventory · MAKI POS Admin';
  }, []);
  const navigate = useNavigate();
  const { data: products, isLoading, error } = useProducts();

  const [search, setSearch] = useState('');
  const [stock, setStock] = useState<ProductFilter['stock']>('all');
  const [category, setCategory] = useState<ProductFilter['category']>('all');
  const [showInactive, setShowInactive] = useState(false);

  const active = useMemo(
    () => (showInactive ? (products ?? []) : (products ?? []).filter((p) => p.isActive)),
    [products, showInactive],
  );

  const counts = useMemo(() => {
    let inStock = 0;
    let lowStock = 0;
    let outOfStock = 0;
    for (const p of active) {
      const s = getStockStatus(p);
      if (s === StockStatus.inStock) inStock += 1;
      else if (s === StockStatus.lowStock) lowStock += 1;
      else outOfStock += 1;
    }
    return { inStock, lowStock, outOfStock };
  }, [active]);

  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const p of active) if (p.category) set.add(p.category);
    return [...set].sort();
  }, [active]);

  const filtered = useMemo(
    () => filterProducts(active, { search, stock, category }),
    [active, search, stock, category],
  );

  const user = useAuthStore((s) => s.user);
  const isAdmin = user?.role === UserRole.admin;
  const totals = useMemo(() => stockTotals(filtered), [filtered]);

  // If the selected category drops out of the option set (e.g. it only existed
  // among inactive products and "Show inactive" was turned off), reset to All so
  // the controlled <select> stays consistent and the table isn't mysteriously empty.
  useEffect(() => {
    if (category !== 'all' && !categories.includes(category)) setCategory('all');
  }, [categories, category]);

  if (error) return <ErrorView title="Could not load inventory" message={error.message} />;

  const toggleStock = (s: StockStatus) => setStock((cur) => (cur === s ? 'all' : s));

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Inventory</h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Products, stock levels, and pricing.
          </p>
        </div>
        <button
          type="button"
          onClick={() => navigate(RoutePaths.productAdd)}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add product
        </button>
      </header>

      <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-3">
        <CountCard label="In stock" value={counts.inStock} active={stock === StockStatus.inStock} tone="green" onClick={() => toggleStock(StockStatus.inStock)} />
        <CountCard label="Low stock" value={counts.lowStock} active={stock === StockStatus.lowStock} tone="orange" onClick={() => toggleStock(StockStatus.lowStock)} />
        <CountCard label="Out of stock" value={counts.outOfStock} active={stock === StockStatus.outOfStock} tone="red" onClick={() => toggleStock(StockStatus.outOfStock)} />
      </div>

      <div className="flex flex-wrap items-center gap-tk-sm">
        <div className="relative max-w-md flex-1">
          <MagnifyingGlassIcon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-light-text-hint" />
          <input
            type="text"
            placeholder="Search by name or SKU…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full rounded-md border border-light-border bg-light-card py-tk-sm pl-9 pr-tk-md text-bodySmall text-light-text outline-none focus:border-light-text"
          />
        </div>
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          className="rounded-md border border-light-border bg-light-card px-tk-sm py-tk-sm text-bodySmall text-light-text"
        >
          <option value="all">All categories</option>
          {categories.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
        <button
          type="button"
          onClick={() => setShowInactive((v) => !v)}
          className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
        >
          {showInactive ? <EyeSlashIcon className="h-3.5 w-3.5" /> : <EyeIcon className="h-3.5 w-3.5" />}
          {showInactive ? 'Hide inactive' : 'Show inactive'}
        </button>
      </div>

      {isAdmin ? (
        <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-3">
          <TotalCard label="Stock Cost" value={formatMoney(totals.cost)} />
          <TotalCard label="Retail Value" value={formatMoney(totals.retail)} />
          <TotalCard label="Expected Profit" value={formatMoney(totals.profit)} />
        </div>
      ) : null}

      {isLoading || !products ? (
        <LoadingView label="Loading inventory…" />
      ) : filtered.length === 0 ? (
        <EmptyState
          title="No products found"
          description={search ? 'Try a different search.' : 'No products match these filters.'}
        />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <table className="w-full text-bodySmall">
            <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
              <tr>
                <Th>Name</Th>
                <Th>SKU</Th>
                <Th>Category</Th>
                <Th>Stock</Th>
                <Th className="text-right">Price</Th>
                <Th className="text-right">Cost</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-light-hairline">
              {filtered.map((p) => {
                const s = getStockStatus(p);
                return (
                  <tr
                    key={p.id}
                    onClick={() => navigate(`/inventory/${p.id}`)}
                    className={cn('cursor-pointer hover:bg-light-subtle', !p.isActive && 'opacity-50')}
                  >
                    <Td className="font-medium text-light-text">
                      {p.name}
                      {!p.isActive ? <span className="ml-tk-xs text-light-text-hint">(inactive)</span> : null}
                    </Td>
                    <Td className="text-light-text-secondary">{p.sku}</Td>
                    <Td className="text-light-text-secondary">{p.category ?? '—'}</Td>
                    <Td>
                      <span className={cn('inline-flex items-center rounded-full px-2 py-[2px] text-[11px] font-medium', STOCK_BADGE[s])}>
                        {p.quantity} · {STOCK_LABEL[s]}
                      </span>
                    </Td>
                    <Td className="text-right text-light-text">{formatMoney(p.price)}</Td>
                    <Td className="text-right text-light-text">{formatMoney(p.cost)}</Td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function CountCard({
  label,
  value,
  active,
  tone,
  onClick,
}: {
  label: string;
  value: number;
  active: boolean;
  tone: 'green' | 'orange' | 'red';
  onClick: () => void;
}) {
  const dot = { green: 'bg-green-500', orange: 'bg-orange-500', red: 'bg-red-500' }[tone];
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'flex items-center justify-between rounded-lg border bg-light-card px-tk-lg py-tk-md text-left transition-colors hover:border-light-text',
        active ? 'border-light-text' : 'border-light-hairline',
      )}
    >
      <span className="flex items-center gap-tk-sm">
        <span className={cn('h-2 w-2 rounded-full', dot)} />
        <span className="text-bodySmall text-light-text-secondary">{label}</span>
      </span>
      <span className="text-headingMedium font-semibold text-light-text">{value}</span>
    </button>
  );
}

function TotalCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-light-hairline bg-light-card px-tk-lg py-tk-md">
      <span className="text-bodySmall text-light-text-secondary">{label}</span>
      <span className="text-headingMedium font-semibold tabular-nums text-light-text">{value}</span>
    </div>
  );
}

function Th({ children, className }: { children: ReactNode; className?: string }) {
  return <th className={cn('px-tk-md py-tk-sm text-left font-medium', className)}>{children}</th>;
}
function Td({ children, className }: { children: ReactNode; className?: string }) {
  return <td className={cn('px-tk-md py-tk-sm', className)}>{children}</td>;
}

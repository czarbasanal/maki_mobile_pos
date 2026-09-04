// Inventory — per design/maki-pos-inventory-redesign and its reference
// (Inventory.dc.html). One summary row (Stock health + the three money
// cards), then saved-view chips with the primary actions, then the filter
// band (search · Category dropdown · Active/Inactive/All · clear · count),
// then the table card with its footer. Status is a filter here — clicking a
// Stock-health row or a view chip filters the table.
import { useEffect, useMemo, useState } from 'react';
import { useNavigate, Outlet } from 'react-router-dom';
import { ArrowDownTrayIcon, PlusIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import { useActiveTags } from '@/presentation/hooks/useTags';
import { RoutePaths } from '@/presentation/router/routePaths';
import { getStockStatus, StockStatus, type Product } from '@/domain/entities';
import { filterProducts, UNTAGGED, type ProductFilter } from '@/domain/products/filterProducts';
import { displaySku } from '@/domain/products/sku';
import { stockTotals } from '@/domain/products/stockTotals';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { ProductImage } from '@/presentation/components/common/ProductImage';
import { TagChips } from './TagChips';
import { TagQuickAttachButton } from './TagQuickAttach';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { MiniBar } from '@/presentation/components/ui/MiniBar';
import { MoneyCard } from '@/presentation/components/ui/MoneyCard';
import { FirstRunState, NoMatchesState } from '@/presentation/components/ui/TableEmptyStates';
import { ViewChips } from '@/presentation/components/ui/ViewChips';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { Segmented } from '@/presentation/components/ui/Segmented';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import { TableFooter } from '@/presentation/components/ui/TableFooter';
import { toast } from '@/presentation/components/ui/toast';
import { toCsv, downloadCsv } from '@/core/utils/csv';
import { formatMoney } from '@/core/utils/money';
import { marginPct, marginToneClass } from '@/domain/products/margin';
import { cn } from '@/core/utils/cn';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import { hasPermission, Permission } from '@/domain/permissions/Permission';

const BUCKETS: Array<{ status: StockStatus; label: string; color: string }> = [
  { status: StockStatus.inStock, label: 'In stock', color: 'var(--pos)' },
  { status: StockStatus.lowStock, label: 'Low stock', color: 'var(--accent)' },
  { status: StockStatus.outOfStock, label: 'Out of stock', color: 'var(--neg)' },
];

/** The rail's 100%: there is no per-part reorderMax yet, so a healthy target
 *  of 3× the reorder point stands in (the low bucket then sits at ≤⅓ bar).
 *  Never below the on-hand count so the fill can't overflow. */
function barBasis(p: Pick<Product, 'quantity' | 'reorderLevel'>): number {
  return Math.max(p.reorderLevel * 3, p.quantity, 1);
}

const STATUS_OPTIONS = [
  { value: 'active', label: 'Active' },
  { value: 'inactive', label: 'Inactive' },
  { value: 'all', label: 'All' },
] as const;

export function InventoryListPage() {
  useEffect(() => {
    document.title = 'Inventory · MAKI POS Admin';
  }, []);
  const navigate = useNavigate();
  const { data: products, isLoading, error } = useProducts();
  const { data: activeTags } = useActiveTags();
  const tagList = activeTags ?? [];

  const [search, setSearch] = useState('');
  const [stock, setStock] = useState<ProductFilter['stock']>('all');
  const [category, setCategory] = useState<ProductFilter['category']>('all');
  const [status, setStatus] = useState<ProductFilter['status']>('active');
  const [tag, setTag] = useState<string | 'all'>('all');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('inventory');

  const all = useMemo(() => products ?? [], [products]);
  // The summary band reads on the whole SELLABLE catalog (reference treats it
  // as whole-catalog, and archived parts aren't stock) — it never moves with
  // the filters below it.
  const catalog = useMemo(() => all.filter((p) => p.isActive), [all]);

  const health = useMemo(() => {
    const counts = { inStock: 0, lowStock: 0, outOfStock: 0 };
    for (const p of catalog) {
      const s = getStockStatus(p);
      if (s === StockStatus.inStock) counts.inStock += 1;
      else if (s === StockStatus.lowStock) counts.lowStock += 1;
      else counts.outOfStock += 1;
    }
    return counts;
  }, [catalog]);

  const totals = useMemo(() => stockTotals(catalog), [catalog]);
  const blendedMargin = totals.retail > 0 ? (totals.profit / totals.retail) * 100 : 0;

  // Everything EXCEPT the stock view — chip counts must not contradict the
  // rows they'd show (guide §5: statusCounts ignore the status filter but
  // respect category, search, and the active/archived state).
  const activeTagIds = useMemo(() => tagList.map((t) => t.id), [tagList]);
  const scoped = useMemo(
    () => filterProducts(all, { search, stock: 'all', category, status, tag, activeTagIds }),
    [all, search, category, status, tag, activeTagIds],
  );
  const viewCounts = useMemo(() => {
    const counts: Record<'all' | StockStatus, number> = {
      all: scoped.length,
      [StockStatus.inStock]: 0,
      [StockStatus.lowStock]: 0,
      [StockStatus.outOfStock]: 0,
    };
    for (const p of scoped) counts[getStockStatus(p)] += 1;
    return counts;
  }, [scoped]);

  const filtered = useMemo(
    () => (stock === 'all' ? scoped : scoped.filter((p) => getStockStatus(p) === stock)),
    [scoped, stock],
  );
  usePageClamp(page, setPage, filtered.length, pageSize);

  // Filters changed — a page number from the previous result set may now
  // point past the end (or simply be stale), so snap back to page 1.
  useEffect(() => {
    setPage(1);
  }, [search, stock, category, status, tag]);

  const paged = useMemo(
    () => filtered.slice((page - 1) * pageSize, page * pageSize),
    [filtered, page, pageSize],
  );

  // Category options respect search + active state (same rule as the chips).
  const categoryOptions = useMemo(() => {
    const base = filterProducts(all, { search, stock: 'all', category: 'all', status });
    const byName = new Map<string, number>();
    for (const p of base) if (p.category) byName.set(p.category, (byName.get(p.category) ?? 0) + 1);
    return [...byName.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([name, count]) => ({ value: name, label: name, count }));
  }, [all, search, status]);

  const user = useAuthStore((s) => s.user);
  const isAdmin = user?.role === UserRole.admin;
  // viewProductCost is admin-only (and password-gated on the phone) — per-item
  // cost is the shop's secret. Margin derives straight from cost, so it
  // carries the same lock.
  const canSeeCost = !!user && hasPermission(user.role, Permission.viewProductCost);
  const canAddProduct = !!user && hasPermission(user.role, Permission.addProduct);

  // If the selected category drops out of the option set (e.g. it only existed
  // among inactive products and the state filter changed), reset to All so the
  // table isn't mysteriously empty.
  useEffect(() => {
    if (category !== 'all' && !categoryOptions.some((c) => c.value === category)) {
      setCategory('all');
    }
  }, [categoryOptions, category]);

  // Same rule as the category reset: if the selected tag disappears from the
  // active list (deleted or deactivated), fall back to All rather than show
  // a mysteriously-empty table.
  useEffect(() => {
    if (tag !== 'all' && tag !== UNTAGGED && !tagList.some((t) => t.id === tag)) {
      setTag('all');
    }
  }, [tagList, tag]);

  // The state segmented counts as a filter too — without it, an Inactive
  // view over zero archived products shows a Clear button that does nothing.
  const isFiltered =
    stock !== 'all' ||
    category !== 'all' ||
    search.trim() !== '' ||
    status !== 'active' ||
    tag !== 'all';
  const clearFilters = () => {
    setStock('all');
    setCategory('all');
    setSearch('');
    setStatus('active');
    setTag('all');
    setPage(1);
  };

  const tagNameById = useMemo(() => new Map(tagList.map((t) => [t.id, t.name])), [tagList]);

  const exportCsv = () => {
    const headers = [
      'Name', 'SKU', 'Category', 'Tags', 'Stock', ...(canSeeCost ? ['Cost'] : []), 'Price', 'Active',
    ];
    const rows = filtered.map((p) => [
      p.name,
      displaySku(p.sku),
      p.category ?? '',
      p.tagIds.map((id) => tagNameById.get(id)).filter(Boolean).join('; '),
      p.quantity,
      ...(canSeeCost ? [p.cost] : []),
      p.price,
      p.isActive ? 'yes' : 'no',
    ]);
    downloadCsv('inventory.csv', toCsv(headers, rows));
    toast.success('Export ready', `${filtered.length} rows`);
  };

  const columns: Array<Column<Product>> = [
    {
      key: 'product', header: 'Product',
      render: (p) => (
        <div className="flex min-w-0 items-center gap-3">
          <ProductImage
            src={p.imageUrl}
            alt={p.name}
            size="sm"
            className="h-[38px] w-[38px] shrink-0 rounded-[9px]"
          />
          <span className="min-w-0 text-ctl-sm font-medium tracking-[-0.1px] text-ink">
            {p.name}
            {!p.isActive ? <span className="ml-1.5 text-ink-3">(inactive)</span> : null}
          </span>
        </div>
      ),
    },
    {
      key: 'sku', header: 'SKU', mono: true, width: '120px',
      render: (p) => (
        <span className="flex items-center gap-1.5 whitespace-nowrap text-[11.5px] text-ink-2">
          {displaySku(p.sku)}
          <CopyButton value={p.sku} label="SKU" />
        </span>
      ),
    },
    {
      key: 'category', header: 'Category',
      render: (p) =>
        p.category ? (
          <span className="whitespace-nowrap rounded-[6px] bg-surface-3 px-2 py-[3px] text-[11px] font-medium text-ink-2">
            {p.category}
          </span>
        ) : (
          <span className="text-ink-3">—</span>
        ),
    },
    {
      key: 'tags', header: 'Tags',
      render: (p) => (
        <div className="flex items-center gap-1.5" onClick={(e) => e.stopPropagation()}>
          <TagChips tagIds={p.tagIds} tags={tagList} />
          <TagQuickAttachButton product={p} tags={tagList} />
        </div>
      ),
    },
    {
      key: 'stock', header: 'Stock', width: '190px',
      render: (p) => {
        const s = getStockStatus(p);
        const barColor =
          s === StockStatus.outOfStock
            ? 'var(--neg)'
            : s === StockStatus.lowStock
              ? 'var(--accent-line)'
              : 'var(--pos)';
        const labelCls =
          s === StockStatus.outOfStock
            ? 'text-neg'
            : s === StockStatus.lowStock
              ? 'text-accent-text'
              : 'text-ink-2';
        return (
          <div className="flex items-center gap-2.5">
            <MiniBar pct={(p.quantity / barBasis(p)) * 100} color={barColor} />
            <span
              className={cn(
                'w-[66px] whitespace-nowrap text-right font-mono text-[11.5px] font-semibold',
                labelCls,
              )}
            >
              {p.quantity <= 0 ? 'none' : `${p.quantity} on hand`}
            </span>
          </div>
        );
      },
    },
    ...(canSeeCost
      ? [
          {
            key: 'cost', header: 'Cost', align: 'right', width: '104px', mono: true,
            render: (p) => <span className="text-ink-2">{formatMoney(p.cost)}</span>,
          } satisfies Column<Product>,
        ]
      : []),
    {
      key: 'price', header: 'Price', align: 'right', width: '104px', mono: true,
      render: (p) => <span className="text-[13px] font-semibold">{formatMoney(p.price)}</span>,
    },
    ...(canSeeCost
      ? [
          {
            key: 'margin', header: 'Margin', align: 'right', width: '82px', mono: true,
            render: (p) => {
              const m = marginPct(p.price, p.cost);
              if (m === null) return <span className="text-ink-3">—</span>;
              return <span className={cn('text-[12px] font-semibold', marginToneClass(m))}>{m}%</span>;
            },
          } satisfies Column<Product>,
        ]
      : []),
  ];

  if (error) return <ErrorView title="Could not load inventory" message={error.message} />;

  const firstRun = !isLoading && all.length === 0;
  const totalCatalog = catalog.length;
  const share = (n: number) => (totalCatalog > 0 ? (n / totalCatalog) * 100 : 0);

  return (
    <div className="flex flex-col gap-3">
      {/* Summary row — Stock health + money cards */}
      <div className="grid grid-cols-[repeat(auto-fit,minmax(230px,1fr))] gap-3">
        <div className="flex flex-col gap-[11px] rounded-card border border-line bg-surface px-[17px] py-[15px] shadow-card">
          <div className="flex items-baseline gap-[9px]">
            <span className="text-[11.5px] font-medium text-ink-2">Stock health</span>
            <span className="ml-auto font-mono text-[11.5px] text-ink-3">
              {totalCatalog.toLocaleString('en-PH')} SKUs
            </span>
          </div>
          <div className="flex h-2 gap-[2px] overflow-hidden rounded-[4px]">
            <div style={{ width: `${share(health.inStock)}%`, background: 'var(--pos)' }} />
            <div style={{ width: `${share(health.lowStock)}%`, background: 'var(--accent)' }} />
            <div style={{ width: `${share(health.outOfStock)}%`, background: 'var(--neg)' }} />
          </div>
          <div className="flex flex-col gap-[7px]">
            {BUCKETS.map((b) => {
              const active = stock === b.status;
              const value =
                b.status === StockStatus.inStock
                  ? health.inStock
                  : b.status === StockStatus.lowStock
                    ? health.lowStock
                    : health.outOfStock;
              return (
                <button
                  key={b.status}
                  type="button"
                  aria-pressed={active}
                  onClick={() => {
                    setStock((cur) => (cur === b.status ? 'all' : b.status));
                    setPage(1);
                  }}
                  className="flex items-center gap-2 py-[2px] text-left"
                >
                  <span
                    aria-hidden
                    className="h-[7px] w-[7px] shrink-0 rounded-[2px]"
                    style={{ background: b.color }}
                  />
                  <span
                    className={cn(
                      'text-[12px]',
                      active ? 'font-semibold text-ink' : 'font-medium text-ink-2',
                    )}
                  >
                    {b.label}
                  </span>
                  <span className="ml-auto font-mono text-[13px] font-semibold text-ink">
                    {value.toLocaleString('en-PH')}
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        {isAdmin ? (
          <>
            <MoneyCard label="Stock cost" value={formatMoney(totals.cost)} note="at latest cost" />
            <MoneyCard label="Retail value" value={formatMoney(totals.retail)} note="at current price" />
            <MoneyCard
              label="Expected profit"
              value={formatMoney(totals.profit)}
              note={`${blendedMargin.toFixed(1)}% blended margin`}
              positive
            />
          </>
        ) : null}
      </div>

      {/* Views row — saved-view chips | Add product + Export */}
      <div className="flex flex-wrap items-center gap-2">
        <ViewChips
          options={[
            { value: 'all' as const, label: 'All', count: viewCounts.all },
            ...BUCKETS.map((b) => ({ value: b.status, label: b.label, count: viewCounts[b.status] })),
          ]}
          value={stock}
          onChange={(v) => {
            setStock(v);
            setPage(1);
          }}
        />
        <div className="ml-auto flex items-center gap-[9px]">
          {canAddProduct ? (
            <Button
              variant="primary"
              icon={<PlusIcon className="h-3.5 w-3.5" />}
              onClick={() => navigate(RoutePaths.productAdd)}
            >
              Add product
            </Button>
          ) : null}
          <button
            type="button"
            title="Export CSV"
            onClick={exportCsv}
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-ctl border border-line bg-surface text-ink-2 hover:border-accent-line hover:text-ink"
          >
            <ArrowDownTrayIcon className="h-[15px] w-[15px]" />
          </button>
        </div>
      </div>

      {/* Filters row */}
      <div className="flex flex-wrap items-center gap-2.5">
        <div className="w-[290px]">
          <SearchInput
            variant="bar"
            value={search}
            onChange={(v) => {
              setSearch(v);
              setPage(1);
            }}
            placeholder="Search name, SKU, barcode, or category"
          />
        </div>
        <SelectFilter
          label="Category"
          value={category === 'all' ? '' : category}
          options={categoryOptions}
          onChange={(v) => {
            setCategory(v || 'all');
            setPage(1);
          }}
          allLabel="All categories"
          allTriggerLabel="All"
        />
        <SelectFilter
          label="Tag"
          value={tag === 'all' ? '' : tag}
          options={[
            { value: UNTAGGED, label: 'Untagged' },
            ...tagList.map((t) => ({ value: t.id, label: t.name })),
          ]}
          onChange={(v) => {
            setTag(v || 'all');
            setPage(1);
          }}
          allLabel="All tags"
          allTriggerLabel="All"
        />
        <Segmented
          label="Product state"
          options={[...STATUS_OPTIONS]}
          value={status}
          onChange={(v) => {
            setStatus(v);
            setPage(1);
          }}
        />
        {isFiltered ? (
          <button
            type="button"
            onClick={clearFilters}
            className="border-b border-line text-[11.5px] text-ink-3 hover:text-neg"
          >
            Clear filters
          </button>
        ) : null}
        <span className="ml-auto font-mono text-[12px] text-ink-3">
          {filtered.length.toLocaleString('en-PH')} {filtered.length === 1 ? 'product' : 'products'}
        </span>
      </div>

      {/* Table card */}
      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        <DataTable
          columns={columns}
          rows={paged}
          rowKey={(p) => p.id}
          onRowClick={(p) => navigate(`/inventory/${p.id}/edit`)}
          loading={isLoading}
          minWidth="1010px"
          empty={
            firstRun ? (
              <FirstRunState
                icon={
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--accent-text)" strokeWidth="1.6">
                    <path d="M12 3.2 20 7.4v9.2L12 20.8 4 16.6V7.4Z" />
                    <path d="M4 7.4 12 11.6l8-4.2" />
                    <line x1="12" y1="11.6" x2="12" y2="20.8" />
                  </svg>
                }
                title="No products yet"
                description="Add your parts to start selling. Set a cost and a price on each one and the register will handle the rest."
              >
                {canAddProduct ? (
                  <Button
                    variant="primary"
                    icon={<PlusIcon className="h-3.5 w-3.5" />}
                    onClick={() => navigate(RoutePaths.productAdd)}
                  >
                    Add product
                  </Button>
                ) : null}
              </FirstRunState>
            ) : (
              <NoMatchesState
                title="No products match these filters"
                hint="Try another category, or clear the search."
                onClear={clearFilters}
              />
            )
          }
        />
        {filtered.length > 0 ? (
          <TableFooter
            total={filtered.length}
            page={page}
            pageSize={pageSize}
            onPage={setPage}
            onPageSize={(n) => {
              setPageSize(n);
              setPage(1);
            }}
          />
        ) : null}
      </section>

      {/* The product drawer (/inventory/:id) renders here, over this list. */}
      <Outlet />
    </div>
  );
}

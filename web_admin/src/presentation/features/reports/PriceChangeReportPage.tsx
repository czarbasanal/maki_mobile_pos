// Price changes (reports guide §1): four KPIs off the SCOPED set, reason
// GROUP chips with counts, search, CopyButton on every SKU, and the delta as
// a signed chip inline with the price (a rise reads --neg, a cut --pos —
// confirm polarity with the client). Two empties: an empty range explains and
// offers a way out; an empty filter result is a different message.
import { useEffect, useMemo, useState } from 'react';
import { TagIcon } from '@heroicons/react/24/outline';
import { usePriceChangeReport } from '@/presentation/hooks/usePriceChangeReport';
import type { PriceChangeRow } from '@/domain/products/priceChangeReport';
import { priceChangeCounts, REASON_GROUPS, reasonGroup, type ReasonGroupKey } from '@/domain/products/priceChangeReason';
import { useProducts } from '@/presentation/hooks/useProducts';
import { formatMoney } from '@/core/utils/money';
import { toCsv, downloadCsv } from '@/core/utils/csv';
import { csvSku } from '@/domain/products/sku';
import { matchesProductQuery } from '@/domain/products/productSearch';
import { StatCard } from '@/presentation/components/ui/StatCard';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { ViewChips } from '@/presentation/components/ui/ViewChips';
import { Badge } from '@/presentation/components/ui/Badge';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { NoMatchesState } from '@/presentation/components/ui/TableEmptyStates';
import { ErrorState } from '@/presentation/components/ui/ErrorState';
import { ReportHeader } from './ReportHeader';
import { EmptyRangeState } from './EmptyRangeState';
import { useReportRange } from './useReportRange';
import { csvFileName, dayLabel } from './reportFormat';

const csvSigned = (v: number) => (v >= 0 ? '+' : '') + v.toFixed(2);

/** One price-change-CSV row. Exported for a focused pinning test on the leading-zero-safe SKU display.
 *  Option (index 3) sits right after SKU (index 2, pinned) — blank for a base row,
 *  the selling option's label otherwise. */
export function priceChangeCsvRow(
  r: PriceChangeRow,
  product: { name: string; sku: string } | undefined,
): (string | number)[] {
  return [
    r.entry.changedAt.toISOString(),
    product?.name ?? r.entry.productId,
    csvSku(product?.sku ?? ''),
    r.entry.optionLabel ?? '',
    r.entry.price.toFixed(2),
    r.hasPrior ? csvSigned(r.priceDelta) : '',
    r.entry.cost.toFixed(2),
    r.hasPrior ? csvSigned(r.costDelta) : '',
    r.entry.reason ?? '',
    r.entry.changedBy,
  ];
}

/** Signed delta chip: hidden when there is no prior or nothing moved. */
function DeltaChip({ delta, hasPrior }: { delta: number; hasPrior: boolean }) {
  if (!hasPrior || delta === 0) return null;
  return (
    <Badge tone={delta > 0 ? 'negative' : 'positive'} shape="chip">
      {csvSigned(delta)}
    </Badge>
  );
}

type ReasonFilter = ReasonGroupKey | 'all';

export function PriceChangeReportPage() {
  const range = useReportRange('last30');
  const { rows: scoped, isLoading, error, refetch } = usePriceChangeReport(range.effectiveRange);
  const products = useProducts().data ?? [];
  const [query, setQuery] = useState('');
  const [reason, setReason] = useState<ReasonFilter>('all');

  const productById = useMemo(() => {
    const m = new Map<string, { name: string; sku: string }>();
    for (const p of products) m.set(p.id, { name: p.name, sku: p.sku });
    return m;
  }, [products]);

  useEffect(() => {
    document.title = 'Price changes · MAKI POS Admin';
  }, []);

  // KPIs and chip counts read the SCOPED set; only the table narrows further.
  const counts = useMemo(() => priceChangeCounts(scoped), [scoped]);
  // A reason whose chip dropped out of the new range reads as All — a
  // render-derived fallback (same rule as Expenses' category), never a
  // setState reset, so the choice heals back when the range widens again.
  const effectiveReason: ReasonFilter = reason !== 'all' && counts.byGroup[reason] === 0 ? 'all' : reason;
  const filtered = useMemo(() => {
    const q = query.trim();
    return scoped.filter((r) => {
      if (effectiveReason !== 'all' && reasonGroup(r.entry.reason).key !== effectiveReason) return false;
      if (!q) return true;
      const p = productById.get(r.entry.productId);
      // The shared matcher (every product search box on web): per-token,
      // order-insensitive, dashed-SKU folding. The option label rides in
      // the name so a "By 3" row stays findable.
      return matchesProductQuery(
        { name: `${p?.name ?? r.entry.productId} ${r.entry.optionLabel ?? ''}`, sku: p?.sku ?? '' },
        q,
      );
    });
  }, [scoped, effectiveReason, query, productById]);
  const isFiltered = effectiveReason !== 'all' || query.trim() !== '';
  const clearFilters = () => {
    setReason('all');
    setQuery('');
  };

  const exportCsv = () => {
    const headers = ['Date', 'Product', 'SKU', 'Option', 'New Price', 'Price Delta', 'New Cost', 'Cost Delta', 'Reason', 'Changed By'];
    downloadCsv(
      csvFileName('price-changes', range.effectiveRange),
      toCsv(headers, filtered.map((r) => priceChangeCsvRow(r, productById.get(r.entry.productId)))),
    );
  };

  const columns: Array<Column<PriceChangeRow>> = [
    {
      key: 'product', header: 'Product',
      render: (r) => (
        <div className="flex min-w-0 flex-col gap-0.5">
          <span className="text-ctl-md font-medium text-ink">{productById.get(r.entry.productId)?.name ?? r.entry.productId}</span>
          {r.entry.optionLabel ? <span className="text-[10.5px] text-ink-3">{r.entry.optionLabel}</span> : null}
        </div>
      ),
    },
    {
      key: 'sku', header: 'SKU', width: '136px',
      render: (r) => {
        const sku = productById.get(r.entry.productId)?.sku ?? '';
        return (
          <div className="flex items-center gap-1.5">
            <span className="whitespace-nowrap font-mono text-[11.5px] text-ink-2">{sku}</span>
            {sku ? <CopyButton value={sku} label="SKU" /> : null}
          </div>
        );
      },
    },
    {
      key: 'reason', header: 'Reason', width: '122px',
      render: (r) => {
        const g = reasonGroup(r.entry.reason);
        return (
          <Badge tone={g.tone} shape="tag" title={r.entry.reason ?? undefined}>
            {g.label}
          </Badge>
        );
      },
    },
    {
      key: 'price', header: 'Price', align: 'right', width: '150px',
      render: (r) => (
        <div className="flex items-center justify-end gap-[7px]">
          <DeltaChip delta={r.priceDelta} hasPrior={r.hasPrior} />
          <span className="font-mono text-[13px] font-semibold text-ink">{formatMoney(r.entry.price)}</span>
        </div>
      ),
    },
    {
      key: 'cost', header: 'New cost', align: 'right', width: '124px',
      render: (r) => (
        <div className="flex items-center justify-end gap-[7px]">
          <DeltaChip delta={r.costDelta} hasPrior={r.hasPrior} />
          <span className="font-mono text-ctl-md text-ink-2">{formatMoney(r.entry.cost)}</span>
        </div>
      ),
    },
    { key: 'when', header: 'When', align: 'right', width: '104px', mono: true, render: (r) => <span className="text-[11.5px] text-ink-3">{dayLabel(r.entry.changedAt)}</span> },
  ];

  const chipOptions = [
    { value: 'all' as ReasonFilter, label: 'All', count: counts.logged },
    ...REASON_GROUPS.filter((g) => counts.byGroup[g.key] > 0).map((g) => ({
      value: g.key as ReasonFilter,
      label: g.label,
      count: counts.byGroup[g.key],
    })),
  ];

  if (error) return <ErrorState message="Could not load price changes." onRetry={refetch} />;

  return (
    <div className="flex flex-col gap-3">
      <ReportHeader range={range} onExport={exportCsv} exportDisabled={filtered.length === 0} />

      <div className="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] gap-3">
        <StatCard lead label="Changes logged" value={counts.logged} format="number" note={range.rangeNote} loading={isLoading} />
        <StatCard label="Price increases" value={counts.increases} format="number" loading={isLoading}
          note={counts.increases === 0 ? 'none in range' : 'products repriced up'} />
        <StatCard label="Price cuts" value={counts.cuts} format="number" loading={isLoading}
          note={counts.cuts === 0 ? 'none in range' : 'products repriced down'} />
        <StatCard label="New products" value={counts.newProducts} format="number" loading={isLoading}
          note={counts.newProducts === 0 ? 'none in range' : 'first price set'} />
      </div>

      <div className="flex flex-wrap items-center gap-2.5">
        <div className="w-[280px]">
          <SearchInput variant="bar" value={query} onChange={setQuery} placeholder="Search product or SKU" />
        </div>
        <ViewChips options={chipOptions} value={effectiveReason} onChange={setReason} />
        <span className="ml-auto font-mono text-[12px] text-ink-3">
          {filtered.length.toLocaleString('en-PH')} {filtered.length === 1 ? 'change' : 'changes'}
        </span>
      </div>

      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        <DataTable
          columns={columns}
          rows={filtered}
          rowKey={(r) => `${r.entry.productId}-${r.entry.id}`}
          loading={isLoading}
          minWidth="880px"
          empty={
            scoped.length === 0 ? (
              <EmptyRangeState
                icon={<TagIcon className="h-[22px] w-[22px] text-ink-3" />}
                title="No price changes in this range"
                description={`Nothing was repriced ${range.rangeNote}. Prices change when stock is received or edited on a product.`}
                onWiden={range.widen}
                widenLabel={range.widenLabel}
              />
            ) : (
              <NoMatchesState
                title="No price changes match these filters"
                hint="Try another reason, or clear the search."
                onClear={isFiltered ? clearFilters : undefined}
              />
            )
          }
        />
      </section>
    </div>
  );
}

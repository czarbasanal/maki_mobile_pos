import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeftIcon, ArrowDownTrayIcon } from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import { usePriceChangeReport } from '@/presentation/hooks/usePriceChangeReport';
import type { PriceChangeRow } from '@/domain/products/priceChangeReport';
import { useProducts } from '@/presentation/hooks/useProducts';
import { formatMoney } from '@/core/utils/money';
import { toCsv, downloadCsv } from '@/core/utils/csv';
import { csvSku } from '@/domain/products/sku';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

const csvSigned = (v: number) => (v >= 0 ? '+' : '') + v.toFixed(2);
const stamp = (d: Date) => d.toISOString().slice(0, 10);

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

export function PriceChangeReportPage() {
  const [range, setRange] = useState<DateRange>(() => resolvePreset('thisMonth'));
  const { rows, isLoading, error } = usePriceChangeReport(range);
  const products = useProducts().data ?? [];

  const productById = useMemo(() => {
    const m = new Map<string, { name: string; sku: string }>();
    for (const p of products) m.set(p.id, { name: p.name, sku: p.sku });
    return m;
  }, [products]);

  useEffect(() => {
    document.title = 'Price changes · MAKI POS Admin';
  }, []);

  const exportCsv = () => {
    const headers = [
      'Date', 'Product', 'SKU', 'Option', 'New Price', 'Price Delta', 'New Cost',
      'Cost Delta', 'Reason', 'Changed By',
    ];
    const body = rows.map((r) => priceChangeCsvRow(r, productById.get(r.entry.productId)));
    downloadCsv(
      `price-changes-${stamp(range.start)}-${stamp(range.end)}.csv`,
      toCsv(headers, body),
    );
  };

  return (
    <div className="space-y-tk-xl">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <Link
          to={RoutePaths.reports}
          className="inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
        >
          <ArrowLeftIcon className="h-3.5 w-3.5" /> Reports
        </Link>
        <div className="flex items-center gap-tk-md">
          <DateRangePicker onChange={setRange} />
          <button
            type="button"
            onClick={exportCsv}
            disabled={rows.length === 0}
            className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-50"
          >
            <ArrowDownTrayIcon className="h-3.5 w-3.5" /> CSV
          </button>
        </div>
      </header>

      {error ? (
        <ErrorView title="Could not load price changes" message={error.message} />
      ) : isLoading ? (
        <div className="h-32">
          <LoadingView label="Loading…" />
        </div>
      ) : (
        <section className="rounded-lg border border-light-hairline bg-light-card p-tk-lg">
          {rows.length === 0 ? (
            <p className="text-bodySmall text-light-text-hint">
              No price changes in this range.
            </p>
          ) : (
            <table className="w-full text-bodySmall">
              <thead className="text-light-text-secondary">
                <tr>
                  <th className="py-tk-xs text-left font-medium">Product</th>
                  <th className="py-tk-xs text-left font-medium">SKU</th>
                  <th className="py-tk-xs text-left font-medium">Option</th>
                  <th className="py-tk-xs text-right font-medium">New Price</th>
                  <th className="py-tk-xs text-right font-medium">Δ</th>
                  <th className="py-tk-xs text-right font-medium">New Cost</th>
                  <th className="py-tk-xs text-right font-medium">Δ</th>
                  <th className="py-tk-xs text-left font-medium">Reason</th>
                  <th className="py-tk-xs text-left font-medium">When</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-light-hairline">
                {rows.map((r) => {
                  const p = productById.get(r.entry.productId);
                  return (
                    <tr key={`${r.entry.productId}-${r.entry.id}`}>
                      <td className="py-tk-xs">{p?.name ?? r.entry.productId}</td>
                      <td className="py-tk-xs text-light-text-secondary">{p?.sku ?? ''}</td>
                      <td className="py-tk-xs text-light-text-secondary">{r.entry.optionLabel ?? ''}</td>
                      <td className="py-tk-xs text-right tabular-nums">{formatMoney(r.entry.price)}</td>
                      <td className={`py-tk-xs text-right tabular-nums ${r.priceDelta > 0 ? 'text-error-dark' : r.priceDelta < 0 ? 'text-success-dark' : 'text-light-text-hint'}`}>
                        {r.hasPrior && r.priceDelta !== 0 ? csvSigned(r.priceDelta) : ''}
                      </td>
                      <td className="py-tk-xs text-right tabular-nums">{formatMoney(r.entry.cost)}</td>
                      <td className={`py-tk-xs text-right tabular-nums ${r.costDelta > 0 ? 'text-error-dark' : r.costDelta < 0 ? 'text-success-dark' : 'text-light-text-hint'}`}>
                        {r.hasPrior && r.costDelta !== 0 ? csvSigned(r.costDelta) : ''}
                      </td>
                      <td className="py-tk-xs">{r.entry.reason ?? ''}</td>
                      <td className="py-tk-xs text-light-text-secondary">
                        {r.entry.changedAt.toLocaleDateString()}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </section>
      )}
    </div>
  );
}

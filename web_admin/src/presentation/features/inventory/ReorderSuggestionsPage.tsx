import { useEffect, useMemo, useState } from 'react';
import { startOfDay } from 'date-fns';
import { Link } from 'react-router-dom';
import { ArrowDownTrayIcon } from '@heroicons/react/24/outline';
import { REORDER_SALES_CAP, useReorderSuggestions } from '@/presentation/hooks/useReorderSuggestions';
import { CappedNotice } from './CappedNotice';
import type { ReorderParams, ReorderSuggestion } from '@/domain/reorder/computeReorderSuggestions';
import { toCsv, downloadCsv } from '@/core/utils/csv';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';

const WINDOWS = [7, 14, 30, 90];

export function ReorderSuggestionsPage() {
  // Day-stable clock: same timestamp all day, advances on the first render
  // after midnight so the yesterday-ending window never goes stale in a
  // long-lived tab (a frozen mount-time `now` would drop a whole day).
  const todayKey = startOfDay(new Date()).getTime();
  const now = useMemo(() => new Date(todayKey), [todayKey]);
  const [windowDays, setWindowDays] = useState(30);
  const [coverDays, setCoverDays] = useState(14);
  const params: ReorderParams = { windowDays, coverDays };
  const { suggestions, isLoading, error, capped } = useReorderSuggestions(params, now);

  // Editable qty overrides, keyed by product id; reset when recomputed.
  const [overrides, setOverrides] = useState<Record<string, number>>({});
  useEffect(() => {
    setOverrides({});
  }, [suggestions]);

  useEffect(() => {
    document.title = 'Reorder · MAKI POS Admin';
  }, []);

  const finalQty = (productId: string, suggested: number) => overrides[productId] ?? suggested;

  // Group by supplier name, preserving the sorted order.
  const groups = useMemo(() => {
    const m = new Map<string, ReorderSuggestion[]>();
    for (const s of suggestions) {
      const key = s.supplierName ?? 'No supplier';
      const arr = m.get(key) ?? [];
      arr.push(s);
      m.set(key, arr);
    }
    return [...m.entries()];
  }, [suggestions]);

  function exportCsv() {
    const rows = suggestions.map((s) => [
      s.supplierName ?? 'No supplier',
      s.product.sku,
      s.product.name,
      s.product.quantity,
      s.velocityPerDay.toFixed(2),
      finalQty(s.product.id, s.suggestedQty),
    ]);
    const csv = toCsv(
      ['Supplier', 'SKU', 'Name', 'Current stock', 'Velocity/day', 'Order qty'],
      rows,
    );
    downloadCsv(`reorder-${new Date().toISOString().slice(0, 10)}.csv`, csv);
  }

  return (
    <div className="space-y-tk-lg px-tk-xl py-tk-lg">
      <header className="space-y-tk-xs">
        <Link
          to={RoutePaths.inventory}
          className="text-bodySmall text-light-text-secondary hover:underline"
        >
          ← Back to inventory
        </Link>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Reorder suggestions
        </h1>
        <p className="text-bodySmall text-light-text-secondary">
          Suggested order quantity from recent sales velocity × days of cover. Velocity uses
          complete days ending yesterday.
        </p>
      </header>

      <div className="flex flex-wrap items-end gap-tk-md">
        <Control label="Sales window">
          <select value={windowDays} onChange={(e) => setWindowDays(Number(e.target.value))} className={ctl}>
            {WINDOWS.map((w) => (
              <option key={w} value={w}>{w} days</option>
            ))}
          </select>
        </Control>
        <Control label="Days of cover">
          <input type="number" min={0} value={coverDays}
            onChange={(e) => setCoverDays(Number(e.target.value) || 0)} className={ctl} />
        </Control>
        <button type="button" onClick={exportCsv} disabled={suggestions.length === 0}
          className="ml-auto inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-50">
          <ArrowDownTrayIcon className="h-4 w-4" /> Export CSV
        </button>
      </div>

      <CappedNotice capped={capped} cap={REORDER_SALES_CAP} />

      {error ? (
        <ErrorView title="Could not load reorder data" message={error.message} />
      ) : isLoading ? (
        <div className="h-32"><LoadingView label="Crunching sales…" /></div>
      ) : suggestions.length === 0 ? (
        <EmptyState
          title="Nothing to reorder"
          description="No products are below their projected demand for this window."
        />
      ) : (
        <div className="space-y-tk-lg">
          {groups.map(([supplierName, rows]) => (
            <section key={supplierName} className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
              <h2 className="border-b border-light-hairline bg-light-subtle px-tk-md py-tk-sm text-bodySmall font-semibold text-light-text">
                {supplierName}
              </h2>
              <table className="w-full text-bodySmall">
                <thead className="border-b border-light-hairline text-light-text-secondary">
                  <tr>
                    <th className="px-tk-md py-tk-sm text-left font-medium">Product</th>
                    <th className="px-tk-md py-tk-sm text-right font-medium">Current</th>
                    <th className="px-tk-md py-tk-sm text-right font-medium">Velocity/day</th>
                    <th className="px-tk-md py-tk-sm text-right font-medium">Order qty</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-light-hairline">
                  {rows.map((s) => (
                    <tr key={s.product.id}>
                      <td className="px-tk-md py-tk-sm">
                        <span className="font-medium text-light-text">{s.product.name}</span>
                        <span className="ml-tk-sm text-light-text-hint">{s.product.sku}</span>
                      </td>
                      <td className="px-tk-md py-tk-sm text-right tabular-nums">{s.product.quantity}</td>
                      <td className="px-tk-md py-tk-sm text-right tabular-nums">{s.velocityPerDay.toFixed(2)}</td>
                      <td className="px-tk-md py-tk-sm text-right">
                        <input type="number" min={0}
                          value={finalQty(s.product.id, s.suggestedQty)}
                          onChange={(e) =>
                            setOverrides((o) => ({ ...o, [s.product.id]: Math.max(0, Number(e.target.value) || 0) }))
                          }
                          className="w-20 rounded-md border border-light-border bg-light-card px-tk-sm py-[4px] text-right tabular-nums" />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}

const ctl =
  'rounded-md border border-light-border bg-light-card px-tk-md py-[6px] text-bodySmall text-light-text';

function Control({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1 block text-[11px] font-medium uppercase tracking-wider text-light-text-hint">
        {label}
      </span>
      {children}
    </label>
  );
}

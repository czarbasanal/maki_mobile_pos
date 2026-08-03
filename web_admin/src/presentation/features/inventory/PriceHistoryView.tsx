import { useMemo, useState } from 'react';
import {
  PriceMetric,
  buildPriceHistoryRows,
  sparklineSeries,
  derivePriceHistorySource,
  splitPriceHistorySeries,
} from '@/domain/products/priceHistory';
import { useQuery } from '@tanstack/react-query';
import { usePriceHistory } from '@/presentation/hooks/usePriceHistory';
import { useUserRepo } from '@/infrastructure/di/container';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { Sparkline } from './Sparkline';

const METRICS: { value: PriceMetric; label: string }[] = [
  { value: PriceMetric.all, label: 'All' },
  { value: PriceMetric.price, label: 'Price' },
  { value: PriceMetric.cost, label: 'Cost' },
];

function formatDate(d: Date): string {
  return d.toLocaleString('en-PH', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

function Delta({ value, delta }: { value: number; delta: number }) {
  const changed = Math.abs(delta) > 0.01;
  const up = delta > 0;
  return (
    <span className="inline-flex items-center gap-1">
      <span className="font-medium text-light-text">{formatMoney(value)}</span>
      {changed ? (
        <span className={up ? 'text-success-dark' : 'text-error-dark'}>
          {up ? '▲' : '▼'} {formatMoney(Math.abs(delta))}
        </span>
      ) : null}
    </span>
  );
}

export function PriceHistoryView({ productId }: { productId: string }) {
  const [metric, setMetric] = useState<PriceMetric>(PriceMetric.all);
  const [selectedSeriesIndex, setSelectedSeriesIndex] = useState(0);
  const { data, isLoading, error } = usePriceHistory(productId);

  // One-shot directory read (not a live subscription) to resolve actor names;
  // includeInactive so a change made by a since-deactivated user still resolves.
  const userRepo = useUserRepo();
  const { data: users } = useQuery({
    queryKey: ['users', 'directory'],
    queryFn: () => userRepo.list({ includeInactive: true }),
    staleTime: 5 * 60_000,
  });

  const entries = data ?? [];
  const namesById = useMemo(
    () => new Map((users ?? []).map((u) => [u.id, u.displayName])),
    [users],
  );

  // Base price + one series per selling option — buildPriceHistoryRows and the
  // sparkline both diff each entry against the next, so feeding them the raw
  // mixed stream zigzags between per-piece base prices and whole-set option
  // prices. Defensive clamp: series only shrinks if the entries change shape
  // mid-session, which never happens for a fixed productId, but a stale index
  // must never index out of range. The clamp only guards range, not identity:
  // it can't detect a *stable* index quietly pointing at a different series if
  // option ordering ever shifted mid-session. That's unreachable today —
  // usePriceHistory is a one-shot read (react-query, no refetchOnWindowFocus)
  // and PriceHistoryPage remounts this view on every product switch — but if
  // price history ever becomes a live subscription, revisit this.
  const series = useMemo(() => splitPriceHistorySeries(entries), [entries]);
  const selectedIndex = selectedSeriesIndex < series.length ? selectedSeriesIndex : 0;
  const selectedEntries = series[selectedIndex]?.entries ?? [];

  const rows = useMemo(
    () => buildPriceHistoryRows(selectedEntries, metric),
    [selectedEntries, metric],
  );
  const priceSeries = useMemo(() => sparklineSeries(selectedEntries, false), [selectedEntries]);
  const costSeries = useMemo(() => sparklineSeries(selectedEntries, true), [selectedEntries]);

  if (isLoading) {
    return <p className="text-bodySmall text-light-text-secondary">Loading…</p>;
  }
  if (error) {
    return <p className="text-bodySmall text-light-text-secondary">Could not load price history.</p>;
  }
  if (entries.length === 0) {
    return <p className="text-bodySmall text-light-text-secondary">No price changes yet.</p>;
  }

  const showPrice = metric !== PriceMetric.cost;
  const showCost = metric !== PriceMetric.price;
  const canChart = selectedEntries.length >= 2;

  return (
    <div className="space-y-tk-lg">
      {series.length > 1 ? (
        <div className="inline-flex rounded-md border border-light-hairline p-[2px]">
          {series.map((s, i) => (
            <button
              key={s.optionId ?? 'base'}
              type="button"
              onClick={() => setSelectedSeriesIndex(i)}
              className={cn(
                'rounded px-tk-md py-[4px] text-bodySmall transition-colors',
                i === selectedIndex
                  ? 'bg-light-subtle font-semibold text-light-text'
                  : 'text-light-text-secondary hover:text-light-text',
              )}
            >
              {s.label}
            </button>
          ))}
        </div>
      ) : null}

      <div className="inline-flex rounded-md border border-light-hairline p-[2px]">
        {METRICS.map((m) => (
          <button
            key={m.value}
            type="button"
            onClick={() => setMetric(m.value)}
            className={cn(
              'rounded px-tk-md py-[4px] text-bodySmall transition-colors',
              metric === m.value
                ? 'bg-light-subtle font-semibold text-light-text'
                : 'text-light-text-secondary hover:text-light-text',
            )}
          >
            {m.label}
          </button>
        ))}
      </div>

      {canChart ? (
        <div className="space-y-tk-md text-primary-dark">
          {showPrice ? (
            <div>
              <div className="pb-tk-xs text-[11px] uppercase tracking-wider text-light-text-hint">
                Price
              </div>
              <Sparkline values={priceSeries} />
            </div>
          ) : null}
          {showCost ? (
            <div>
              <div className="pb-tk-xs text-[11px] uppercase tracking-wider text-light-text-hint">
                Cost
              </div>
              <Sparkline values={costSeries} />
            </div>
          ) : null}
        </div>
      ) : (
        <p className="text-bodySmall text-light-text-secondary">Not enough changes to chart</p>
      )}

      <div className="overflow-hidden rounded-lg border border-light-hairline">
        <table className="w-full text-bodySmall">
          <thead className="bg-light-subtle text-left text-light-text-secondary">
            <tr>
              <th className="px-tk-md py-tk-sm font-medium">Date</th>
              {showPrice ? <th className="px-tk-md py-tk-sm font-medium">Price</th> : null}
              {showCost ? <th className="px-tk-md py-tk-sm font-medium">Cost</th> : null}
              <th className="px-tk-md py-tk-sm font-medium">Source</th>
              <th className="px-tk-md py-tk-sm font-medium">By</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => (
              <tr
                key={`${r.entry.changedAt.getTime()}-${i}`}
                className="border-t border-light-hairline"
              >
                <td className="px-tk-md py-tk-sm text-light-text">{formatDate(r.entry.changedAt)}</td>
                {showPrice ? (
                  <td className="px-tk-md py-tk-sm">
                    <Delta value={r.entry.price} delta={r.hasPrior ? r.priceDelta : 0} />
                  </td>
                ) : null}
                {showCost ? (
                  <td className="px-tk-md py-tk-sm">
                    <Delta value={r.entry.cost} delta={r.hasPrior ? r.costDelta : 0} />
                  </td>
                ) : null}
                <td className="px-tk-md py-tk-sm text-light-text-secondary">
                  {derivePriceHistorySource(r.entry.reason, r.entry.note)}
                </td>
                <td className="px-tk-md py-tk-sm text-light-text-secondary">
                  {namesById.get(r.entry.changedBy) ?? r.entry.changedBy}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

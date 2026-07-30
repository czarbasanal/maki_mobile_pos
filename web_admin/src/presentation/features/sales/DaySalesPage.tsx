// A single day's sales as expandable tiles — the "View all" destination from
// the dashboard's Recent sales panel. useDaySales() (via SaleRepository.list)
// already returns every sale with .items populated, so expand is a purely
// local toggle — no per-tile fetch.
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { addDays, format, subDays } from 'date-fns';
import { ChevronDownIcon, ChevronRightIcon } from '@heroicons/react/24/outline';
import { useDaySales } from '@/presentation/hooks/useDaySales';
import {
  saleGrandTotal,
  saleIsPercentageDiscount,
  saleIsVoided,
  saleItemHasOption,
  saleItemNet,
  saleItemOptionSets,
  type Sale,
} from '@/domain/entities';
import { PaymentMethod, paymentMethodDisplayName } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { colors } from '@/core/theme/tokens';
import { RoutePaths } from '@/presentation/router/routePaths';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Pager } from '@/presentation/components/common/Pager';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';

const timeFmt = new Intl.DateTimeFormat('en-PH', {
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

export function DaySalesPage() {
  const [date, setDate] = useState(() => new Date());
  const { sales, isLoading, error } = useDaySales(date);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('daySales');
  usePageClamp(page, setPage, sales.length, pageSize);
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(new Set());

  useEffect(() => {
    document.title = 'Day sales · MAKI POS Admin';
  }, []);

  // Day changed — a page number / expanded tile from the previous day may no
  // longer make sense, so reset both.
  useEffect(() => {
    setPage(1);
    setExpanded(new Set());
  }, [date]);

  const pagedSales = useMemo(
    () => sales.slice((page - 1) * pageSize, page * pageSize),
    [sales, page, pageSize],
  );

  function toggle(sale: Sale) {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(sale.id)) next.delete(sale.id);
      else next.add(sale.id);
      return next;
    });
  }

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Day sales
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            All sales for the selected day.
          </p>
        </div>
        <div className="flex items-center gap-tk-sm">
          <button
            type="button"
            aria-label="Previous day"
            onClick={() => setDate((d) => subDays(d, 1))}
            className="rounded-md border border-light-border px-tk-sm py-[8px] text-bodySmall text-light-text hover:bg-light-subtle"
          >
            ← Prev day
          </button>
          <input
            type="date"
            aria-label="Date"
            value={format(date, 'yyyy-MM-dd')}
            onChange={(e) => {
              if (!e.target.value) return;
              setDate(new Date(`${e.target.value}T00:00:00`));
            }}
            className="rounded-md border border-light-border bg-light-card px-tk-md py-[8px] text-bodySmall text-light-text outline-none focus:border-light-text"
          />
          <button
            type="button"
            aria-label="Next day"
            onClick={() => setDate((d) => addDays(d, 1))}
            className="rounded-md border border-light-border px-tk-sm py-[8px] text-bodySmall text-light-text hover:bg-light-subtle"
          >
            Next day →
          </button>
        </div>
      </header>

      {error ? (
        <ErrorView title="Could not load sales" message={error.message} />
      ) : isLoading ? (
        <div className="h-32">
          <LoadingView label="Loading sales…" />
        </div>
      ) : sales.length === 0 ? (
        <EmptyState
          title="No sales this day"
          description="Try a different date, or come back once sales start rolling in."
        />
      ) : (
        <section className="space-y-tk-md">
          <div className="space-y-tk-sm">
            {pagedSales.map((sale) => (
              <SaleTile
                key={sale.id}
                sale={sale}
                expanded={expanded.has(sale.id)}
                onToggle={() => toggle(sale)}
              />
            ))}
          </div>
          <Pager total={sales.length} page={page} onPage={setPage} pageSize={pageSize}
            onPageSize={(n) => { setPageSize(n); setPage(1); }} />
        </section>
      )}
    </div>
  );
}

function SaleTile({
  sale,
  expanded,
  onToggle,
}: {
  sale: Sale;
  expanded: boolean;
  onToggle: () => void;
}) {
  const voided = saleIsVoided(sale);
  const isPct = saleIsPercentageDiscount(sale);
  const total = saleGrandTotal(sale);

  return (
    <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
        className="flex w-full items-center gap-tk-md px-tk-md py-tk-sm text-left hover:bg-light-subtle"
      >
        {expanded ? (
          <ChevronDownIcon className="h-4 w-4 shrink-0 text-light-text-hint" />
        ) : (
          <ChevronRightIcon className="h-4 w-4 shrink-0 text-light-text-hint" />
        )}
        <span
          className={cn(
            'font-mono text-bodySmall font-semibold tabular-nums text-light-text',
            voided && 'text-light-text-hint line-through',
          )}
        >
          {sale.saleNumber}
        </span>
        {voided ? (
          <span className="rounded-full bg-error-light px-tk-xs py-[1px] text-[10px] font-semibold uppercase tracking-wider text-error-dark">
            Void
          </span>
        ) : null}
        <span className="text-bodySmall text-light-text-hint">{timeFmt.format(sale.createdAt)}</span>
        <span className="text-bodySmall text-light-text-secondary">{sale.cashierName}</span>
        <span className="flex-1" />
        <PaymentChip sale={sale} voided={voided} />
        <span
          className={cn(
            'text-bodySmall font-semibold tabular-nums',
            voided ? 'text-light-text-hint line-through' : 'text-light-text',
          )}
        >
          {formatMoney(total)}
        </span>
      </button>

      {expanded ? (
        <div className="border-t border-light-hairline bg-light-subtle px-tk-md py-tk-md">
          <div className="space-y-tk-xs text-bodySmall">
            {sale.items.map((item) => {
              const hasOption = saleItemHasOption(item);
              const sets = saleItemOptionSets(item);
              return (
                <div key={item.id} className="flex justify-between text-light-text">
                  {hasOption ? (
                    <span>
                      <span className="block">
                        {item.name} · {item.optionLabel}
                      </span>
                      {(sets ?? 0) > 1 ? (
                        <span className="block text-[11px] text-light-text-hint">
                          {item.optionLabel} × {sets} ({item.quantity} pcs)
                        </span>
                      ) : null}
                    </span>
                  ) : (
                    <span>
                      {item.quantity} × {item.name}
                    </span>
                  )}
                  <span className="tabular-nums">{formatMoney(saleItemNet(item, isPct))}</span>
                </div>
              );
            })}
            {sale.laborLines.map((l) => (
              <div key={l.id} className="flex justify-between text-light-text">
                <span>🔧 {l.description || 'Service'}</span>
                <span className="tabular-nums">{formatMoney(l.fee)}</span>
              </div>
            ))}
            {sale.feeLines.map((f) => (
              <div key={f.id} className="flex justify-between text-light-text">
                <span>🔧 {f.name || 'Shop fee'}</span>
                <span className="tabular-nums">{formatMoney(f.amount)}</span>
              </div>
            ))}
            <div className="pt-tk-xs">
              <Link
                to={`${RoutePaths.saleDetail.replace(':id', sale.id)}`}
                className="text-bodySmall font-medium text-light-text underline"
              >
                Full detail →
              </Link>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function PaymentChip({ sale, voided }: { sale: Sale; voided: boolean }) {
  const dotColor = voided
    ? colors.pos.voided
    : sale.paymentMethod === PaymentMethod.gcash
      ? colors.pos.gcash
      : colors.pos.cash;
  return (
    <span className="inline-flex items-center gap-tk-xs rounded-full border border-light-hairline bg-light-card px-tk-sm py-[2px] text-[11px] font-medium text-light-text-secondary">
      <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: dotColor }} aria-hidden />
      {paymentMethodDisplayName[sale.paymentMethod]}
    </span>
  );
}

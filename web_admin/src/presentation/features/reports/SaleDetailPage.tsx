import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import { useVoidSale } from '@/presentation/hooks/useVoidSale';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { canVoidSale } from '@/domain/sales/voiding';
import { Dialog } from '@/presentation/components/common/Dialog';
import { Receipt } from './Receipt';
import {
  saleEffectiveTenders,
  saleGrandTotal,
  saleIsPercentageDiscount,
  saleItemNet,
  saleLaborSubtotal,
  salePartsSubtotal,
  saleTotalDiscount,
} from '@/domain/entities';
import { paymentMethodDisplayName, realTenderMethods } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';

const dtFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short' });

export function SaleDetailPage() {
  const { id = '' } = useParams();
  const repo = useSaleRepo();
  const { data: sale, isLoading, error } = useQuery({
    queryKey: ['sales', id],
    queryFn: () => repo.getById(id),
  });

  const voidSale = useVoidSale(id);
  const { data: voidReasons } = useActiveCategories(CategoryKind.voidReason);
  const [voidOpen, setVoidOpen] = useState(false);
  const [reason, setReason] = useState('');

  useEffect(() => {
    document.title = 'Sale detail · MAKI POS Admin';
  }, []);

  if (isLoading) return <div className="p-tk-xl"><LoadingView label="Loading sale…" /></div>;
  if (error) {
    return (
      <div className="p-tk-xl">
        <ErrorView title="Could not load sale" message={(error as Error).message} />
      </div>
    );
  }
  if (!sale) {
    return (
      <div className="p-tk-xl">
        <EmptyState
          title="Sale not found"
          description="It may have been removed."
          action={
            <Link to="/reports/sales" className="text-light-text underline">
              Back to sales
            </Link>
          }
        />
      </div>
    );
  }

  const isPct = saleIsPercentageDiscount(sale);
  const tenders = saleEffectiveTenders(sale);

  return (
    <>
    <div className="space-y-tk-lg px-tk-xl py-tk-lg print:hidden">
      <header className="space-y-tk-xs">
        <Link to="/reports/sales" className="text-bodySmall text-light-text-secondary hover:underline">
          ← Back to sales
        </Link>
        <div className="flex items-center gap-tk-md">
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            {sale.saleNumber}
          </h1>
          {sale.voidedAt ? (
            <span className="rounded-full bg-error-light px-tk-sm py-[2px] text-[11px] font-semibold uppercase tracking-wider text-error-dark">
              Voided
            </span>
          ) : null}
        </div>
        <p className="text-bodySmall text-light-text-secondary">
          {dtFmt.format(sale.createdAt)} · {sale.cashierName}
          {sale.mechanicName ? ` · Mechanic: ${sale.mechanicName}` : ''}
        </p>
      </header>

      <div className="flex flex-wrap gap-tk-sm">
        <button
          type="button"
          onClick={() => window.print()}
          className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle"
        >
          Print receipt
        </button>
        {canVoidSale(sale) ? (
          <button
            type="button"
            onClick={() => {
              setReason('');
              voidSale.reset();
              setVoidOpen(true);
            }}
            className="rounded-md border border-error-light px-tk-md py-tk-sm text-bodySmall font-medium text-error-dark hover:bg-error-light/30"
          >
            Void sale
          </button>
        ) : null}
      </div>

      <section className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <th className="px-tk-md py-tk-sm text-left font-medium">Item</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Unit</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Net</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {sale.items.map((it) => (
              <tr key={it.id}>
                <td className="px-tk-md py-tk-sm">
                  <span className="font-medium text-light-text">{it.name}</span>
                  <span className="ml-tk-sm text-light-text-hint">{it.sku}</span>
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{it.quantity}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(it.unitPrice)}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">
                  {formatMoney(saleItemNet(it, isPct))}
                </td>
              </tr>
            ))}
            {sale.laborLines.map((l) => (
              <tr key={l.id} className="bg-light-subtle">
                <td className="px-tk-md py-tk-sm" colSpan={3}>
                  <span className="text-light-text">🔧 {l.description || 'Service'}</span>
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(l.fee)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="ml-auto w-full max-w-sm space-y-tk-xs rounded-lg border border-light-hairline bg-light-card p-tk-lg text-bodySmall">
        <Row label="Gross Sales" value={formatMoney(salePartsSubtotal(sale))} />
        <Row label="Discount" value={`-${formatMoney(saleTotalDiscount(sale))}`} />
        <Row label="Labor" value={formatMoney(saleLaborSubtotal(sale))} />
        <div className="border-t border-light-hairline pt-tk-xs">
          <Row label="Total" value={formatMoney(saleGrandTotal(sale))} bold />
        </div>
        <div className="mt-tk-sm border-t border-light-hairline pt-tk-sm">
          {realTenderMethods
            .filter((m) => (tenders[m] ?? 0) > 0)
            .map((m) => (
              <Row key={m} label={paymentMethodDisplayName[m]} value={formatMoney(tenders[m] ?? 0)} muted />
            ))}
          <Row label="Amount received" value={formatMoney(sale.amountReceived)} muted />
          <Row label="Change" value={formatMoney(sale.changeGiven)} muted />
        </div>
      </section>

      <Dialog
        open={voidOpen}
        onClose={() => {
          if (!voidSale.isPending) setVoidOpen(false);
        }}
        title="Void sale"
        dismissable={!voidSale.isPending}
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text-secondary">
            Voiding restores the sold stock and removes this sale from reports. This can’t be undone.
          </p>
          {(voidReasons ?? []).length === 0 ? (
            <p className="text-bodySmall text-light-text-secondary">
              No void reasons configured.{' '}
              <Link to="/settings/lists" className="text-light-text underline">
                Add them in Manage lists
              </Link>
              .
            </p>
          ) : (
            <label className="block space-y-tk-xs">
              <span className="text-bodySmall text-light-text-secondary">Reason</span>
              <select
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall"
              >
                <option value="">Select a reason…</option>
                {(voidReasons ?? []).map((r) => (
                  <option key={r.id} value={r.name}>
                    {r.name}
                  </option>
                ))}
              </select>
            </label>
          )}
          {voidSale.error ? (
            <p className="text-bodySmall text-error-dark">{voidSale.error.message}</p>
          ) : null}
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setVoidOpen(false)}
              disabled={voidSale.isPending}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={!reason || voidSale.isPending}
              onClick={async () => {
                try {
                  await voidSale.mutateAsync({ reason });
                  setVoidOpen(false);
                } catch {
                  // surfaced via voidSale.error
                }
              }}
              className="rounded-md bg-error px-tk-md py-tk-sm text-bodySmall font-semibold text-white hover:bg-error-dark disabled:opacity-60"
            >
              {voidSale.isPending ? 'Voiding…' : 'Void sale'}
            </button>
          </div>
        </div>
      </Dialog>
    </div>
    <div id="print-receipt" className="hidden print:block">
      <Receipt sale={sale} />
    </div>
    </>
  );
}

function Row({
  label,
  value,
  bold,
  muted,
}: {
  label: string;
  value: string;
  bold?: boolean;
  muted?: boolean;
}) {
  return (
    <div className="flex justify-between">
      <span className={muted ? 'capitalize text-light-text-hint' : 'capitalize text-light-text-secondary'}>
        {label}
      </span>
      <span className={`tabular-nums ${bold ? 'font-semibold text-light-text' : 'text-light-text'}`}>
        {value}
      </span>
    </div>
  );
}

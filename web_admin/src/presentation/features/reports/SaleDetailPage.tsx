// Sale detail — reskinned per design/JO-Sale-Detail-Hand-off §B: one card,
// four stacked bands. Identity + actions, then the facts strip (the fix for
// the old buried subtitle line), then the items table full width, then
// totals + tender right-aligned in a narrow column.
import { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useJobOrderRepo, useSaleRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useVoidSale } from '@/presentation/hooks/useVoidSale';
import { usePendingVoidRequest, useRequestVoid } from '@/presentation/hooks/useVoidRequest';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { canVoidSale } from '@/domain/sales/voiding';
import { BackLink } from '@/presentation/components/common/BackLink';
import { RoutePaths } from '@/presentation/router/routePaths';
import { feeLineDisplayLabel, saleIsVoided } from '@/domain/entities';
import { cn } from '@/core/utils/cn';
import { Dialog } from '@/presentation/components/common/Dialog';
import { Receipt } from './Receipt';
import {
  saleEffectiveTenders,
  saleFeesTotal,
  saleGrandTotal,
  saleIsPercentageDiscount,
  saleItemHasOption,
  saleItemNet,
  saleItemOptionSetsCaption,
  saleLaborSubtotal,
  salePartsSubtotal,
  saleTotalDiscount,
} from '@/domain/entities';
import { paymentMethodDisplayName, realTenderMethods } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import { formatInShopZone } from '@/domain/time/shopTime';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { PrinterIcon } from '@heroicons/react/24/outline';
import { Badge } from '@/presentation/components/ui/Badge';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { BackButton } from '@/presentation/components/ui/BackButton';
import { Fact } from '@/presentation/components/ui/Fact';
import { displaySku } from '@/domain/products/sku';

export function SaleDetailPage() {
  const { id = '' } = useParams();
  const repo = useSaleRepo();
  const jobOrderRepo = useJobOrderRepo();
  const navigate = useNavigate();
  // Smart back, same rule as BackLink: a deep link / refresh has nothing to
  // go back to (React Router marks the first session entry 'default').
  const location = useLocation();
  const goBack = () =>
    location.key !== 'default' ? navigate(-1) : navigate(RoutePaths.salesReport);
  const { data: sale, isLoading, error } = useQuery({
    queryKey: ['sales', id],
    queryFn: () => repo.getById(id),
  });
  // The originating ticket's NUMBER for the identity chip — the sale only
  // stores the doc id.
  const { data: jobOrder } = useQuery({
    queryKey: ['jobOrders', sale?.jobOrderId ?? ''],
    queryFn: () => jobOrderRepo.getById(sale!.jobOrderId!),
    enabled: !!sale?.jobOrderId,
  });

  const user = useAuthStore((st) => st.user);
  const canVoidDirect = !!user && hasPermission(user.role, Permission.voidSale);
  const canRequestVoid = !!user && hasPermission(user.role, Permission.requestVoidSale);
  const voidSale = useVoidSale(id);
  const requestVoid = useRequestVoid(id);
  const { data: voidPending } = usePendingVoidRequest(id);
  const { data: voidReasons } = useActiveCategories(CategoryKind.voidReason);
  const [voidOpen, setVoidOpen] = useState(false);
  const [requestOpen, setRequestOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [otherDetail, setOtherDetail] = useState('');
  // 'Other' mirrors mobile's RequestVoidDialog: free text, min 5 chars.
  const resolvedReason = reason === 'Other' ? otherDetail.trim() : reason;
  const requestReady = reason === 'Other' ? otherDetail.trim().length >= 5 : !!reason;

  useEffect(() => {
    document.title = 'Sale detail · MAKI POS Admin';
  }, []);

  if (isLoading) return <LoadingView label="Loading sale…" />;
  if (error) {
    return <ErrorView title="Could not load sale" message={(error as Error).message} />;
  }
  if (!sale) {
    return (
      <EmptyState
        title="Sale not found"
        description="It may have been removed."
        action={<BackLink fallback={RoutePaths.salesReport} className="text-ink underline" />}
      />
    );
  }

  const isPct = saleIsPercentageDiscount(sale);
  const voided = saleIsVoided(sale);
  const tenders = saleEffectiveTenders(sale);
  const tenderMethods = realTenderMethods.filter((m) => (tenders[m] ?? 0) > 0);
  const tenderValue =
    tenderMethods.length > 1
      ? 'Split'
      : paymentMethodDisplayName[tenderMethods[0] ?? sale.paymentMethod];
  const tenderSub =
    tenderMethods.length > 1
      ? tenderMethods.map((m) => paymentMethodDisplayName[m]).join(' + ')
      : 'Paid in full';
  const discount = saleTotalDiscount(sale);

  return (
    <>
    <div className="flex flex-col gap-3 print:hidden">
      <BackButton onClick={goBack} />

      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        {/* Band 1 — identity and actions */}
        <div className="flex flex-wrap items-center gap-tk-sm border-b border-line-2 px-5 py-4">
          <h2
            className={cn(
              'flex items-center gap-[7px] font-mono text-[19px] font-semibold tracking-[-0.6px]',
              // Struck through, not just badged: the number and the money are
              // what someone scans for, and a pill alone is easy to miss.
              voided ? 'text-ink-3 line-through' : 'text-ink',
            )}
          >
            {sale.saleNumber}
            <CopyButton value={sale.saleNumber} label="sale number" />
          </h2>
          <Badge tone={voided ? 'negative' : 'positive'}>{voided ? 'Voided' : 'Paid'}</Badge>
          {jobOrder ? (
            <button
              type="button"
              onClick={() => navigate(RoutePaths.jobOrders)}
              title="Back to job orders"
              className="rounded-pill bg-surface-3 px-2.5 py-[3px] font-mono text-[11px] font-medium text-ink-2 hover:text-ink"
            >
              {jobOrder.name}
            </button>
          ) : null}
          <div className="ml-auto flex items-center gap-tk-sm">
            <Button
              variant="primary"
              size="sm"
              icon={<PrinterIcon className="h-3.5 w-3.5" />}
              onClick={() => window.print()}
            >
              Print receipt
            </Button>
            {canVoidSale(sale) && !voidPending && canVoidDirect ? (
              <button
                type="button"
                onClick={() => {
                  setReason('');
                  voidSale.reset();
                  setVoidOpen(true);
                }}
                className="rounded-ctl border border-line px-3.5 py-[7px] text-ctl-sm font-medium text-neg hover:border-neg hover:bg-neg-soft"
              >
                Void sale
              </button>
            ) : null}
            {canVoidSale(sale) && !voidPending && !canVoidDirect && canRequestVoid ? (
              <button
                type="button"
                onClick={() => {
                  setReason('');
                  setOtherDetail('');
                  requestVoid.reset();
                  setRequestOpen(true);
                }}
                className="rounded-ctl border border-line px-3.5 py-[7px] text-ctl-sm font-medium text-neg hover:border-neg hover:bg-neg-soft"
              >
                Request void
              </button>
            ) : null}
          </div>
        </div>

        {voided && sale.voidReason ? (
          <p className="border-b border-line-2 bg-neg-soft px-5 py-2 text-ctl-sm text-neg">
            {`Voided: ${sale.voidReason}${sale.voidedByName ? ` — ${sale.voidedByName}` : ''}`}
          </p>
        ) : null}
        {canVoidSale(sale) && voidPending ? (
          <div className="border-b border-line-2 bg-accent-soft px-5 py-2">
            <p className="text-ctl-sm font-medium text-ink">Void pending approval</p>
            <p className="text-micro text-ink-2">
              {canVoidDirect
                ? 'Approve or reject it from Void Requests.'
                : 'An admin will approve or reject it.'}
            </p>
          </div>
        ) : null}

        {/* Band 2 — the facts strip */}
        <div className="grid grid-cols-[repeat(auto-fit,minmax(160px,1fr))] divide-x divide-line-2 border-b border-line-2">
          <Fact
            label="Date & time"
            value={formatInShopZone(sale.createdAt, { hour: 'numeric', minute: '2-digit', hour12: true })}
            sub={`${formatInShopZone(sale.createdAt, { month: 'short', day: 'numeric', year: 'numeric' })} · ${formatInShopZone(sale.createdAt, { weekday: 'short' })}`}
            mono
          />
          <Fact label="Cashier" value={sale.cashierName || '—'} sub="Cashier on shift" />
          <Fact label="Mechanic" value={sale.mechanicName ?? '—'} sub="Assigned mechanic" />
          <Fact label="Motorcycle" value={sale.motorcycleModel ?? '—'} sub="Motorcycle serviced" />
          <Fact label="Tender" value={tenderValue} sub={tenderSub} />
        </div>

        {/* Band 3 — items, full width */}
        <div className="overflow-x-auto">
          <table className="w-full min-w-[400px] border-collapse">
            <thead>
              <tr className="border-b border-line-2 bg-surface-2">
                <Th>Item</Th>
                <Th className="w-[52px] px-3 text-right">Qty</Th>
                <Th className="w-[92px] px-3 text-right">Unit</Th>
                <Th className="w-[100px] text-right">Net</Th>
              </tr>
            </thead>
            <tbody>
              {sale.items.map((it) => {
                // Name and option label stay in their own differently-coloured
                // spans on this surface (unlike the single-string sites), so
                // only the caption — byte-identical everywhere — is shared via
                // saleItemOptionSetsCaption; saleItemHasOption still guards the
                // label span directly to keep that per-surface styling intact.
                const hasOption = saleItemHasOption(it);
                const caption = saleItemOptionSetsCaption(it);
                return (
                  <tr key={it.id} className="border-b border-line-2 last:border-b-0">
                    <td className="px-5 py-3">
                      <div className="text-cell font-medium text-ink">
                        {it.name}
                        {hasOption ? <span className="text-ink-2"> · {it.optionLabel}</span> : null}
                      </div>
                      <div className="flex items-center gap-[5px] whitespace-nowrap font-mono text-[10.5px] text-ink-3">
                        {displaySku(it.sku)}
                        <CopyButton value={it.sku} label="SKU" />
                      </div>
                      {caption ? <div className="text-micro text-ink-3">{caption}</div> : null}
                    </td>
                    <td className="px-3 py-3 text-right font-mono text-cell text-ink">{it.quantity}</td>
                    <td className="px-3 py-3 text-right font-mono text-cell text-ink-2">
                      {formatMoney(it.unitPrice)}
                    </td>
                    <td className="px-5 py-3 text-right font-mono text-[13px] font-semibold text-ink">
                      {formatMoney(saleItemNet(it, isPct))}
                    </td>
                  </tr>
                );
              })}
              {sale.laborLines.map((l) => (
                <LineRow key={l.id} chip="LABOR" label={l.description || 'Service'} detail={null} amount={l.fee} />
              ))}
              {sale.feeLines.map((f) => (
                <LineRow key={f.id} chip="FEE" label={feeLineDisplayLabel(f) || 'Shop fee'} detail={null} amount={f.amount} />
              ))}
            </tbody>
          </table>
        </div>

        {/* Band 4 — totals, then the tender band (full-width, surface-2),
            both right-aligned in a 340px column */}
        <div className="flex justify-end border-t border-line px-5 py-3.5">
          <div className="flex w-full max-w-[340px] flex-col gap-[9px]">
            <Row label="Parts subtotal" value={formatMoney(salePartsSubtotal(sale))} struck={voided} />
            <Row label="Labor" value={formatMoney(saleLaborSubtotal(sale))} struck={voided} />
            {sale.feeLines.length > 0 ? (
              <Row label="Shop fees" value={formatMoney(saleFeesTotal(sale))} struck={voided} />
            ) : null}
            <div className="flex justify-between text-cell">
              <span className="text-ink-2">Discount</span>
              <span
                className={cn(
                  'font-mono tabular-nums',
                  voided ? 'text-ink-3 line-through' : discount > 0 ? 'text-neg' : 'text-ink-3',
                )}
              >
                {discount > 0 ? `− ${formatMoney(discount)}` : formatMoney(0)}
              </span>
            </div>
            <div className="flex items-baseline justify-between border-t border-line pt-[11px]">
              <span className="text-[13.5px] font-semibold text-ink">Total</span>
              <span
                data-testid="sale-total"
                className={cn(
                  'tnum font-mono text-[23px] font-semibold tracking-[-1px]',
                  voided ? 'text-ink-3 line-through' : 'text-ink',
                )}
              >
                {formatMoney(saleGrandTotal(sale))}
              </span>
            </div>
          </div>
        </div>

        <div className="flex justify-end border-t border-line-2 bg-surface-2 px-5 py-3.5">
          <div className="flex w-full max-w-[340px] flex-col gap-[9px]">
            <p className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">
              Tender · {tenderMethods.map((m) => paymentMethodDisplayName[m]).join(' + ') || paymentMethodDisplayName[sale.paymentMethod]}
            </p>
            {tenderMethods.length > 1
              ? tenderMethods.map((m) => (
                  <Row key={m} label={paymentMethodDisplayName[m]} value={formatMoney(tenders[m] ?? 0)} muted />
                ))
              : null}
            <Row label="Amount received" value={formatMoney(sale.amountReceived)} muted />
            <Row label="Change" value={formatMoney(sale.changeGiven)} muted />
          </div>
        </div>
      </section>

      <Dialog
        open={requestOpen}
        onClose={() => {
          if (!requestVoid.isPending) setRequestOpen(false);
        }}
        title="Request void"
        dismissable={!requestVoid.isPending}
      >
        <div className="space-y-tk-md">
          <p className="text-ctl-sm text-ink-2">
            Sale {sale.saleNumber} will be sent to an admin for approval.
          </p>
          <label className="block space-y-tk-xs">
            <span className="text-ctl-sm text-ink-2">Reason</span>
            <select
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              className="w-full rounded-field border border-line bg-surface-2 px-tk-md py-tk-sm text-ctl-sm text-ink"
            >
              <option value="">Select a reason…</option>
              {(voidReasons ?? []).map((r) => (
                <option key={r.id} value={r.name}>
                  {r.name}
                </option>
              ))}
              <option value="Other">Other</option>
            </select>
          </label>
          {reason === 'Other' ? (
            <label className="block space-y-tk-xs">
              <span className="text-ctl-sm text-ink-2">Reason details (at least 5 characters)</span>
              <textarea
                value={otherDetail}
                onChange={(e) => setOtherDetail(e.target.value)}
                maxLength={200}
                rows={2}
                className="w-full rounded-field border border-line bg-surface-2 px-tk-md py-tk-sm text-ctl-sm text-ink"
              />
            </label>
          ) : null}
          {requestVoid.error ? (
            <p className="text-ctl-sm text-neg">{requestVoid.error.message}</p>
          ) : null}
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setRequestOpen(false)}
              disabled={requestVoid.isPending}
              className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-sm text-ink-2 hover:bg-surface-2"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={!requestReady || requestVoid.isPending}
              onClick={async () => {
                try {
                  await requestVoid.mutateAsync({ sale, reason: resolvedReason });
                  setRequestOpen(false);
                } catch {
                  // surfaced via requestVoid.error
                }
              }}
              className="rounded-ctl bg-neg px-tk-md py-tk-sm text-ctl-sm font-semibold text-white hover:brightness-95 disabled:opacity-60"
            >
              {requestVoid.isPending ? 'Sending…' : 'Send request'}
            </button>
          </div>
        </div>
      </Dialog>

      <Dialog
        open={voidOpen}
        onClose={() => {
          if (!voidSale.isPending) setVoidOpen(false);
        }}
        title="Void sale"
        dismissable={!voidSale.isPending}
      >
        <div className="space-y-tk-md">
          <p className="text-ctl-sm text-ink-2">
            Voiding restores the sold stock and removes this sale from reports. This can’t be undone.
          </p>
          {(voidReasons ?? []).length === 0 ? (
            <p className="text-ctl-sm text-ink-2">
              No void reasons configured.{' '}
              <Link to="/settings/lists" className="text-ink underline">
                Add them in Manage lists
              </Link>
              .
            </p>
          ) : (
            <label className="block space-y-tk-xs">
              <span className="text-ctl-sm text-ink-2">Reason</span>
              <select
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                className="w-full rounded-field border border-line bg-surface-2 px-tk-md py-tk-sm text-ctl-sm text-ink"
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
          {voidSale.error ? <p className="text-ctl-sm text-neg">{voidSale.error.message}</p> : null}
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setVoidOpen(false)}
              disabled={voidSale.isPending}
              className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-sm text-ink-2 hover:bg-surface-2"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={!reason || voidSale.isPending}
              onClick={async () => {
                try {
                  await voidSale.mutateAsync({
                    reason,
                    saleNumber: sale.saleNumber,
                    amount: saleGrandTotal(sale),
                  });
                  setVoidOpen(false);
                } catch {
                  // surfaced via voidSale.error
                }
              }}
              className="rounded-ctl bg-neg px-tk-md py-tk-sm text-ctl-sm font-semibold text-white hover:brightness-95 disabled:opacity-60"
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

function Th({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <th className={cn('px-5 py-2 text-left text-micro-caps uppercase text-ink-3', className)}>
      {children}
    </th>
  );
}

/** A labor/fee row in the items table: chip + description, — in Qty/Unit. */
function LineRow({
  chip,
  label,
  detail,
  amount,
}: {
  chip: string;
  label: string;
  detail: string | null;
  amount: number;
}) {
  return (
    <tr className="border-b border-line-2 last:border-b-0">
      <td className="px-5 py-3">
        <span className="flex items-center gap-[9px]">
          <span className="rounded-[5px] bg-info-soft px-[7px] py-0.5 text-[9.5px] font-bold tracking-[0.8px] text-info">
            {chip}
          </span>
          <span className="text-cell text-ink">{label}</span>
          {detail ? <span className="text-micro text-ink-3">{detail}</span> : null}
        </span>
      </td>
      <td className="px-3 py-3 text-right font-mono text-cell text-ink-3">—</td>
      <td className="px-3 py-3 text-right font-mono text-cell text-ink-3">—</td>
      <td className="px-5 py-3 text-right font-mono text-[13px] font-semibold text-ink">
        {formatMoney(amount)}
      </td>
    </tr>
  );
}

function Row({
  label,
  value,
  muted,
  struck,
}: {
  label: string;
  value: string;
  muted?: boolean;
  /** Voided sale: the amount no longer stands. */
  struck?: boolean;
}) {
  return (
    <div className="flex justify-between text-cell">
      <span className={muted ? 'capitalize text-ink-3' : 'capitalize text-ink-2'}>{label}</span>
      <span
        className={cn(
          'font-mono tabular-nums',
          struck ? 'text-ink-3 line-through' : 'text-ink',
        )}
      >
        {value}
      </span>
    </div>
  );
}

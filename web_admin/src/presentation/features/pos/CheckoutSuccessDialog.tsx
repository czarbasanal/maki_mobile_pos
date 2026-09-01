// Post-sale success dialog (mobile checkout_success_dialog.dart parity):
// the CHANGE DUE hero the cashier reads aloud, totals, completion-time
// stock warnings, and the way to the receipt. The cart clears only on the
// way out — an interrupted session keeps its idempotent checkoutId, so a
// retry can never double-record the sale.
import { CheckCircleIcon } from '@heroicons/react/24/outline';
import { Dialog } from '@/presentation/components/common/Dialog';
import { formatMoney } from '@/core/utils/money';
import type { StockShortfall } from '@/domain/sales/cart';

export interface CheckoutSuccessDialogProps {
  saleNumber: string;
  grandTotal: number;
  amountReceived: number;
  changeGiven: number;
  warnings: StockShortfall[];
  onViewReceipt: () => void;
  onDone: () => void;
}

export function CheckoutSuccessDialog({
  saleNumber,
  grandTotal,
  amountReceived,
  changeGiven,
  warnings,
  onViewReceipt,
  onDone,
}: CheckoutSuccessDialogProps) {
  return (
    <Dialog open onClose={onDone} title="Sale completed" dismissable={false}>
      <div className="space-y-tk-md text-center">
        <CheckCircleIcon className="mx-auto h-10 w-10 text-pos" />
        <p className="font-mono text-cell text-ink-2">{saleNumber}</p>

        <div className="rounded-card bg-surface-2 px-tk-md py-tk-md">
          <p className="text-micro font-semibold uppercase tracking-wide text-ink-2">
            Change due
          </p>
          <p className="tnum font-mono text-kpi font-bold text-ink">
            {formatMoney(changeGiven)}
          </p>
        </div>

        <div className="flex justify-between text-cell text-ink-2">
          <span>Total {formatMoney(grandTotal)}</span>
          <span>Received {formatMoney(amountReceived)}</span>
        </div>

        {warnings.length > 0 ? (
          <div className="rounded-ctl border border-accent-text/40 bg-accent-soft px-tk-md py-tk-sm text-left">
            <p className="text-ctl-sm font-semibold text-accent-text">Stock warnings</p>
            <ul className="mt-tk-xs space-y-[2px] text-ctl-sm text-accent-text">
              {warnings.map((w) => (
                <li key={w.productId}>
                  {w.name} — sold {w.requested}, only {w.onHand} on hand
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <div className="flex justify-center gap-tk-sm pt-tk-xs">
          <button
            type="button"
            onClick={onViewReceipt}
            className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-md text-ink-2 hover:bg-surface-2"
          >
            View receipt
          </button>
          <button
            type="button"
            onClick={onDone}
            className="rounded-ctl bg-accent px-tk-lg py-tk-sm text-ctl-md font-semibold text-accent-ink hover:brightness-95"
          >
            Done
          </button>
        </div>
      </div>
    </Dialog>
  );
}

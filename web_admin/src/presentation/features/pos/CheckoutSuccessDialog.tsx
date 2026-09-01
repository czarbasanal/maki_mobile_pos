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
        <CheckCircleIcon className="mx-auto h-10 w-10 text-success" />
        <p className="font-mono text-bodySmall text-light-text-secondary">{saleNumber}</p>

        <div className="rounded-lg bg-light-subtle px-tk-md py-tk-md">
          <p className="text-[11px] font-semibold uppercase tracking-wide text-light-text-secondary">
            Change due
          </p>
          <p className="text-headingLarge font-bold tabular-nums text-light-text">
            {formatMoney(changeGiven)}
          </p>
        </div>

        <div className="flex justify-between text-bodySmall text-light-text-secondary">
          <span>Total {formatMoney(grandTotal)}</span>
          <span>Received {formatMoney(amountReceived)}</span>
        </div>

        {warnings.length > 0 ? (
          <div className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-left">
            <p className="text-[12px] font-semibold text-warning-dark">Stock warnings</p>
            <ul className="mt-tk-xs space-y-[2px] text-[12px] text-warning-dark">
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
            className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text-secondary hover:bg-light-subtle"
          >
            View receipt
          </button>
          <button
            type="button"
            onClick={onDone}
            className="rounded-md bg-light-text px-tk-lg py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
          >
            Done
          </button>
        </div>
      </div>
    </Dialog>
  );
}

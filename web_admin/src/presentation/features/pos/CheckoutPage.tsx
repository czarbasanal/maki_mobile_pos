import { useEffect, useState } from 'react';
import { Navigate, Link, useNavigate } from 'react-router-dom';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useCheckout } from '@/presentation/hooks/useCheckout';
import { usePaymentDraft } from '@/presentation/hooks/usePaymentDraft';
import { cartGrandTotal, cartHasBillableContent } from '@/domain/sales/cart';
import { describedLaborLines, laborValidationError } from '@/domain/sales/labor';
import { chargeableFeeLines } from '@/domain/entities';
import { useRegisterStatus } from '@/presentation/hooks/useRegisterStatus';
import { useProducts } from '@/presentation/hooks/useProducts';
import { stockShortfalls, type StockShortfall } from '@/domain/sales/cart';
import { CheckoutSuccessDialog } from './CheckoutSuccessDialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { PaymentSection } from './PaymentSection';
import { OrderSummary } from './OrderSummary';
import { cn } from '@/core/utils/cn';

export function CheckoutPage() {
  const lines = useCartStore((s) => s.lines);
  const discountType = useCartStore((s) => s.discountType);
  const laborLines = useCartStore((s) => s.laborLines);
  const feeLines = useCartStore((s) => s.feeLines);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const mechanicName = useCartStore((s) => s.mechanicName);
  const motorcycleModel = useCartStore((s) => s.motorcycleModel);
  const jobOrderId = useCartStore((s) => s.jobOrderId);
  const notes = useCartStore((s) => s.notes);
  const clear = useCartStore((s) => s.clear);
  const ensureCheckoutId = useCartStore((s) => s.ensureCheckoutId);
  const checkout = useCheckout();
  const navigate = useNavigate();
  const { previousDayUnsettled } = useRegisterStatus();
  const { data: liveProducts } = useProducts();
  const [completed, setCompleted] = useState<{
    saleId: string;
    saleNumber: string;
    grandTotal: number;
    amountReceived: number;
    changeGiven: number;
    warnings: StockShortfall[];
  } | null>(null);

  const grandTotal = cartGrandTotal(lines, laborLines, discountType, feeLines);
  const pay = usePaymentDraft(grandTotal);

  useEffect(() => {
    document.title = 'Checkout';
  }, []);

  // Labor-only and fee-only tickets are legitimate sales (mobile parity) —
  // only a cart with nothing billable bounces back. Never while the success
  // dialog is deciding where to go.
  if (!completed && !cartHasBillableContent(lines, laborLines, feeLines)) {
    return <Navigate to={RoutePaths.pos} replace />;
  }

  const laborError = laborValidationError(laborLines, mechanicId);
  // Mobile's bill-out rule: no model, no conversion (walk-ins unaffected).
  const billOutNeedsModel = jobOrderId !== null && !motorcycleModel;
  const canComplete =
    pay.isValid &&
    !checkout.isPending &&
    laborError === null &&
    !previousDayUnsettled &&
    !billOutNeedsModel;
  const onComplete = async () => {
    try {
      const sale = await checkout.mutateAsync({
        checkoutId: ensureCheckoutId(),
        lines,
        discountType,
        paymentMethod: pay.paymentMethod,
        tenders: pay.tenders,
        amountReceived: pay.amountReceived,
        changeGiven: pay.changeGiven,
        laborLines: describedLaborLines(laborLines),
        feeLines: chargeableFeeLines(feeLines),
        mechanicId,
        mechanicName,
        motorcycleModel,
        jobOrderId,
        notes,
      });
      // The cart stays intact until Done — the idempotent checkoutId makes an
      // interrupted session's retry return this same recorded sale.
      setCompleted({
        saleId: sale.id,
        saleNumber: sale.saleNumber,
        grandTotal,
        amountReceived: pay.amountReceived,
        changeGiven: pay.changeGiven,
        warnings: stockShortfalls(lines, liveProducts ?? []),
      });
    } catch {
      // surfaced via checkout.error
    }
  };

  const finishAnd = (destination: 'pos' | 'receipt') => {
    if (!completed) return;
    const { saleId, saleNumber } = completed;
    pay.reset();
    clear();
    if (destination === 'receipt') {
      navigate(`/reports/sale/${saleId}`);
    } else {
      navigate(RoutePaths.pos, { replace: true, state: { completedSaleNumber: saleNumber } });
    }
  };

  return (
    <div className="mx-auto max-w-xl space-y-tk-md">
      <Link to={RoutePaths.pos} className="text-cell text-ink-2 hover:text-ink">
        ← Back to cart
      </Link>

      {previousDayUnsettled ? (
        <p className="rounded-ctl border border-accent-text/40 bg-accent-soft px-tk-md py-tk-sm text-cell text-accent-text">
          Yesterday's sales haven't been closed yet. Close the day on the register phone before
          completing new sales.
        </p>
      ) : null}

      {laborError ? (
        <p className="rounded-ctl border border-accent-text/40 bg-accent-soft px-tk-md py-tk-sm text-cell text-accent-text">
          {laborError}
        </p>
      ) : null}

      {billOutNeedsModel ? (
        <p className="rounded-ctl border border-accent-text/40 bg-accent-soft px-tk-md py-tk-sm text-cell text-accent-text">
          Set the motorcycle model before billing out this Job Order.
        </p>
      ) : null}

      {checkout.error ? (
        <p className="rounded-ctl border border-neg/40 bg-neg-soft px-tk-md py-tk-sm text-cell text-neg">
          {checkout.error.message}
        </p>
      ) : null}

      <OrderSummary lines={lines} discountType={discountType} laborLines={laborLines} feeLines={feeLines} />

      <div className="space-y-tk-sm rounded-card border border-line bg-surface p-tk-md shadow-card">
        <PaymentSection pay={pay} grandTotal={grandTotal} />
        <button
          type="button"
          disabled={!canComplete}
          onClick={onComplete}
          className={cn(
            'w-full rounded-ctl bg-accent px-tk-md py-tk-sm text-ctl-md font-semibold text-accent-ink hover:brightness-95',
            !canComplete && 'cursor-not-allowed opacity-60',
          )}
        >
          {checkout.isPending ? 'Completing…' : 'Complete sale'}
        </button>
      </div>

      {completed ? (
        <CheckoutSuccessDialog
          saleNumber={completed.saleNumber}
          grandTotal={completed.grandTotal}
          amountReceived={completed.amountReceived}
          changeGiven={completed.changeGiven}
          warnings={completed.warnings}
          onViewReceipt={() => finishAnd('receipt')}
          onDone={() => finishAnd('pos')}
        />
      ) : null}
    </div>
  );
}

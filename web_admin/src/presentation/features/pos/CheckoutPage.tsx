import { useEffect } from 'react';
import { Navigate, Link, useNavigate } from 'react-router-dom';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useCheckout } from '@/presentation/hooks/useCheckout';
import { usePaymentDraft } from '@/presentation/hooks/usePaymentDraft';
import { cartGrandTotal, cartHasBillableContent } from '@/domain/sales/cart';
import { describedLaborLines, laborValidationError } from '@/domain/sales/labor';
import { useRegisterStatus } from '@/presentation/hooks/useRegisterStatus';
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

  const grandTotal = cartGrandTotal(lines, laborLines, discountType, feeLines);
  const pay = usePaymentDraft(grandTotal);

  useEffect(() => {
    document.title = 'Checkout';
  }, []);

  // Labor-only and fee-only tickets are legitimate sales (mobile parity) —
  // only a cart with nothing billable bounces back.
  if (!cartHasBillableContent(lines, laborLines, feeLines)) {
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
        feeLines,
        mechanicId,
        mechanicName,
        motorcycleModel,
        jobOrderId,
        notes,
      });
      pay.reset();
      clear();
      navigate(RoutePaths.pos, { replace: true, state: { completedSaleNumber: sale.saleNumber } });
    } catch {
      // surfaced via checkout.error
    }
  };

  return (
    <div className="mx-auto max-w-xl space-y-tk-md">
      <Link to={RoutePaths.pos} className="text-bodySmall text-light-text-secondary hover:text-light-text">
        ← Back to cart
      </Link>

      {previousDayUnsettled ? (
        <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
          Yesterday's sales haven't been closed yet. Close the day on the register phone before
          completing new sales.
        </p>
      ) : null}

      {laborError ? (
        <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
          {laborError}
        </p>
      ) : null}

      {billOutNeedsModel ? (
        <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
          Set the motorcycle model before billing out this Job Order.
        </p>
      ) : null}

      {checkout.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {checkout.error.message}
        </p>
      ) : null}

      <OrderSummary lines={lines} discountType={discountType} laborLines={laborLines} feeLines={feeLines} />

      <div className="space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-md">
        <PaymentSection pay={pay} grandTotal={grandTotal} />
        <button
          type="button"
          disabled={!canComplete}
          onClick={onComplete}
          className={cn(
            'w-full rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark',
            !canComplete && 'cursor-not-allowed opacity-60',
          )}
        >
          {checkout.isPending ? 'Completing…' : 'Complete sale'}
        </button>
      </div>
    </div>
  );
}

import { useEffect } from 'react';
import { Navigate, Link, useNavigate } from 'react-router-dom';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useCheckout } from '@/presentation/hooks/useCheckout';
import { usePaymentDraft } from '@/presentation/hooks/usePaymentDraft';
import { cartGrandTotal } from '@/domain/sales/cart';
import { describedLaborLines } from '@/domain/sales/labor';
import { RoutePaths } from '@/presentation/router/routePaths';
import { PaymentSection } from './PaymentSection';
import { OrderSummary } from './OrderSummary';
import { cn } from '@/core/utils/cn';

export function CheckoutPage() {
  const lines = useCartStore((s) => s.lines);
  const discountType = useCartStore((s) => s.discountType);
  const laborLines = useCartStore((s) => s.laborLines);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const mechanicName = useCartStore((s) => s.mechanicName);
  const draftId = useCartStore((s) => s.draftId);
  const clear = useCartStore((s) => s.clear);
  const checkout = useCheckout();
  const navigate = useNavigate();

  const grandTotal = cartGrandTotal(lines, laborLines, discountType);
  const pay = usePaymentDraft(grandTotal);

  useEffect(() => {
    document.title = 'Checkout';
  }, []);

  if (lines.length === 0) return <Navigate to={RoutePaths.pos} replace />;

  const canComplete = pay.isValid && !checkout.isPending;
  const onComplete = async () => {
    try {
      const sale = await checkout.mutateAsync({
        lines,
        discountType,
        paymentMethod: pay.paymentMethod,
        tenders: pay.tenders,
        amountReceived: pay.amountReceived,
        changeGiven: pay.changeGiven,
        laborLines: describedLaborLines(laborLines),
        mechanicId,
        mechanicName,
        draftId,
      });
      pay.reset();
      clear();
      navigate(RoutePaths.pos, { state: { completedSaleNumber: sale.saleNumber } });
    } catch {
      // surfaced via checkout.error
    }
  };

  return (
    <div className="mx-auto max-w-xl space-y-tk-md px-tk-xl py-tk-lg">
      <Link to={RoutePaths.pos} className="text-bodySmall text-light-text-secondary hover:text-light-text">
        ← Back to cart
      </Link>
      <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Checkout</h1>

      {checkout.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {checkout.error.message}
        </p>
      ) : null}

      <OrderSummary lines={lines} discountType={discountType} laborLines={laborLines} />

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

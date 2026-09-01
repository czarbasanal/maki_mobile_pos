// Totals block (POS guide §2): --surface-2 fill inside the cart card,
// 12.5px rows with mono values, discount as −₱x in --neg, then a rule
// and the 23px mono Total.
import { cartSubtotal, cartDiscount, cartGrandTotal, cartFeesTotal, type CartLine } from '@/domain/sales/cart';
import { cartLaborSubtotal } from '@/domain/sales/labor';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { FeeLine } from '@/domain/entities/FeeLine';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';

export function CartTotals({
  lines,
  discountType,
  laborLines,
  feeLines = [],
}: {
  lines: CartLine[];
  discountType: DiscountType;
  laborLines: LaborLine[];
  feeLines?: FeeLine[];
}) {
  const subtotal = cartSubtotal(lines, discountType);
  const discount = cartDiscount(lines, discountType);
  const labor = cartLaborSubtotal(laborLines);
  const fees = cartFeesTotal(feeLines);
  const total = cartGrandTotal(lines, laborLines, discountType, feeLines);
  return (
    <dl className="space-y-tk-xs rounded-b-card border-t border-line-2 bg-surface-2 px-[18px] py-4">
      <Row label="Parts subtotal" value={formatMoney(subtotal)} />
      {discount > 0 ? <Row label="Discount" value={`− ${formatMoney(discount)}`} negative /> : null}
      {labor > 0 ? <Row label="Labor" value={formatMoney(labor)} /> : null}
      {fees > 0 ? <Row label="Shop fees" value={formatMoney(fees)} /> : null}
      <div className="flex items-baseline justify-between border-t border-line pt-tk-sm">
        <dt className="text-cell text-ink-2">Total</dt>
        <dd className="tnum font-mono text-kpi text-ink">{formatMoney(total)}</dd>
      </div>
    </dl>
  );
}

function Row({ label, value, negative }: { label: string; value: string; negative?: boolean }) {
  return (
    <div className="flex justify-between text-cell">
      <dt className="text-ink-2">{label}</dt>
      <dd className={cn('font-mono tabular-nums', negative ? 'text-neg' : 'text-ink')}>{value}</dd>
    </div>
  );
}

import { cartSubtotal, cartDiscount, cartGrandTotal, type CartLine } from '@/domain/sales/cart';
import { cartLaborSubtotal } from '@/domain/sales/labor';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { LaborLine } from '@/domain/entities/LaborLine';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';

export function CartTotals({
  lines,
  discountType,
  laborLines,
}: {
  lines: CartLine[];
  discountType: DiscountType;
  laborLines: LaborLine[];
}) {
  const subtotal = cartSubtotal(lines, discountType);
  const discount = cartDiscount(lines, discountType);
  const labor = cartLaborSubtotal(laborLines);
  const total = cartGrandTotal(lines, laborLines, discountType);
  return (
    <dl className="space-y-tk-xs border-t border-light-hairline px-tk-md py-tk-sm text-bodySmall">
      <Row label="Subtotal" value={formatMoney(subtotal)} />
      <Row label="Discount" value={`− ${formatMoney(discount)}`} />
      {labor > 0 ? <Row label="Labor" value={formatMoney(labor)} /> : null}
      <Row label="Total" value={formatMoney(total)} strong />
    </dl>
  );
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div className="flex justify-between">
      <dt className="text-light-text-hint">{label}</dt>
      <dd className={cn('text-light-text tabular-nums', strong && 'font-semibold')}>{value}</dd>
    </div>
  );
}

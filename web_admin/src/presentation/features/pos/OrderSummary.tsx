import { cartSubtotal, cartDiscount, cartGrandTotal, type CartLine } from '@/domain/sales/cart';
import { cartLaborSubtotal, describedLaborLines } from '@/domain/sales/labor';
import { saleItemNet } from '@/domain/entities/SaleItem';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { LaborLine } from '@/domain/entities/LaborLine';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';

export function OrderSummary({
  lines,
  discountType,
  laborLines,
}: {
  lines: CartLine[];
  discountType: DiscountType;
  laborLines: LaborLine[];
}) {
  const isPct = discountType === DiscountType.percentage;
  const subtotal = cartSubtotal(lines, discountType);
  const discount = cartDiscount(lines, discountType);
  const labor = cartLaborSubtotal(laborLines);
  const total = cartGrandTotal(lines, laborLines, discountType);
  const described = describedLaborLines(laborLines);

  return (
    <div className="rounded-lg border border-light-hairline bg-light-card">
      <div className="border-b border-light-hairline px-tk-md py-tk-sm text-bodyMedium font-semibold text-light-text">
        Order summary
      </div>
      <ul className="divide-y divide-light-hairline">
        {lines.map((l) => (
          <li key={l.productId} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm text-bodySmall">
            <span className="min-w-0">
              <span className="block text-light-text">{l.name}</span>
              <span className="block text-[12px] text-light-text-hint">
                {l.quantity} × {formatMoney(l.unitPrice)}
              </span>
            </span>
            <span className="font-medium text-light-text tabular-nums">{formatMoney(saleItemNet(l, isPct))}</span>
          </li>
        ))}
        {described.map((l) => (
          <li key={l.id} className="flex items-center justify-between gap-tk-md bg-light-subtle px-tk-md py-tk-sm text-bodySmall">
            <span className="text-light-text">🔧 {l.description || 'Service'}</span>
            <span className="font-medium text-light-text tabular-nums">{formatMoney(l.fee)}</span>
          </li>
        ))}
      </ul>
      <dl className="space-y-tk-xs border-t border-light-hairline px-tk-md py-tk-sm text-bodySmall">
        <Row label="Subtotal" value={formatMoney(subtotal)} />
        <Row label="Discount" value={`− ${formatMoney(discount)}`} />
        {labor > 0 ? <Row label="Labor" value={formatMoney(labor)} /> : null}
        <Row label="Total" value={formatMoney(total)} strong />
      </dl>
    </div>
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

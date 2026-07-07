import type { CartLine } from '@/domain/sales/cart';
import { describedLaborLines } from '@/domain/sales/labor';
import { saleItemNet } from '@/domain/entities/SaleItem';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { LaborLine } from '@/domain/entities/LaborLine';
import { formatMoney } from '@/core/utils/money';
import { CartTotals } from './CartTotals';

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
      <CartTotals lines={lines} discountType={discountType} laborLines={laborLines} />
    </div>
  );
}

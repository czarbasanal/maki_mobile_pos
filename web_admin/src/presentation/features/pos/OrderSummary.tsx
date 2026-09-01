import type { CartLine } from '@/domain/sales/cart';
import { feeLineDisplayLabel } from '@/domain/entities';
import { describedLaborLines } from '@/domain/sales/labor';
import { saleItemDisplayName, saleItemNet, saleItemOptionSetsCaption } from '@/domain/entities/SaleItem';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { FeeLine } from '@/domain/entities/FeeLine';
import { formatMoney } from '@/core/utils/money';
import { CartTotals } from './CartTotals';

export function OrderSummary({
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
  const isPct = discountType === DiscountType.percentage;
  const described = describedLaborLines(laborLines);

  return (
    <div className="rounded-card border border-line bg-surface shadow-card">
      <div className="border-b border-line-2 px-tk-md py-tk-sm text-card-title text-ink">
        Order summary
      </div>
      <ul className="divide-y divide-line-2">
        {lines.map((l) => {
          const caption = saleItemOptionSetsCaption(l);
          return (
            <li key={l.id} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm text-cell">
              <span className="min-w-0">
                <span className="block text-ink">{saleItemDisplayName(l)}</span>
                <span className="block text-ctl-sm text-ink-3">
                  {l.quantity} × {formatMoney(l.unitPrice)}
                </span>
                {caption ? (
                  <span className="block text-ctl-sm text-ink-3">{caption}</span>
                ) : null}
              </span>
              <span className="font-mono font-medium tabular-nums text-ink">{formatMoney(saleItemNet(l, isPct))}</span>
            </li>
          );
        })}
        {described.map((l) => (
          <li key={l.id} className="flex items-center justify-between gap-tk-md bg-surface-2 px-tk-md py-tk-sm text-cell">
            <span className="text-ink">🔧 {l.description || 'Service'}</span>
            <span className="font-mono font-medium tabular-nums text-ink">{formatMoney(l.fee)}</span>
          </li>
        ))}
        {feeLines.map((l) => (
          <li key={l.id} className="flex items-center justify-between gap-tk-md bg-surface-2 px-tk-md py-tk-sm text-cell">
            <span className="text-ink">{feeLineDisplayLabel(l) || 'Shop fee'}</span>
            <span className="font-mono font-medium tabular-nums text-ink">{formatMoney(l.amount)}</span>
          </li>
        ))}
      </ul>
      <CartTotals lines={lines} discountType={discountType} laborLines={laborLines} feeLines={feeLines} />
    </div>
  );
}

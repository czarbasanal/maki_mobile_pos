import {
  saleGrandTotal,
  saleIsVoided,
  saleTotalItemCount,
  type Sale,
} from '@/domain/entities';
import { PaymentMethod, paymentMethodDisplayName } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { colors } from '@/core/theme/tokens';

const timeFmt = new Intl.DateTimeFormat('en-PH', {
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

export function RecentSales({ sales, limit = 8 }: { sales: Sale[]; limit?: number }) {
  if (sales.length === 0) {
    return <EmptyState title="No sales today" description="Transactions will appear here as they happen." />;
  }

  return (
    <ul className="divide-y divide-light-hairline">
      {sales.slice(0, limit).map((sale) => (
        <RecentSaleRow key={sale.id} sale={sale} />
      ))}
    </ul>
  );
}

function RecentSaleRow({ sale }: { sale: Sale }) {
  const voided = saleIsVoided(sale);
  const itemCount = saleTotalItemCount(sale);
  const total = saleGrandTotal(sale);
  const paymentColor =
    sale.paymentMethod === PaymentMethod.gcash ? colors.pos.gcash : colors.pos.cash;
  const dotColor = voided ? colors.pos.voided : paymentColor;

  return (
    <li className="flex items-center gap-tk-md py-tk-sm">
      <span
        className="h-2 w-2 shrink-0 rounded-full"
        style={{ backgroundColor: dotColor }}
        aria-hidden
      />
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-tk-sm">
          <span
            className={cn(
              'text-bodySmall font-semibold tabular-nums text-light-text',
              voided && 'line-through text-light-text-hint',
            )}
          >
            {sale.saleNumber}
          </span>
          {voided ? (
            <span className="rounded-full bg-error-light px-tk-xs py-[1px] text-[10px] font-semibold uppercase tracking-wider text-error-dark">
              Void
            </span>
          ) : null}
          <span className="text-[12px] text-light-text-hint">
            {paymentMethodDisplayName[sale.paymentMethod]}
          </span>
        </div>
        <div className="mt-[2px] text-[12px] text-light-text-hint">
          {itemCount} item{itemCount === 1 ? '' : 's'} · {timeFmt.format(sale.createdAt)}
        </div>
      </div>
      <div
        className={cn(
          'text-bodySmall font-semibold tabular-nums',
          voided ? 'line-through text-light-text-hint' : 'text-light-text',
        )}
      >
        {formatMoney(total)}
      </div>
    </li>
  );
}

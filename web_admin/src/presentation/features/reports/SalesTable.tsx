import { Link } from 'react-router-dom';
import {
  saleGrandTotal,
  saleIsVoided,
  saleTotalItemCount,
  type Sale,
} from '@/domain/entities';
import { paymentMethodDisplayName } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { EmptyState } from '@/presentation/components/common/EmptyState';

const dtFmt = new Intl.DateTimeFormat('en-PH', {
  month: 'short',
  day: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

function Th({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <th className={cn('px-tk-md py-tk-sm text-left font-medium', className)}>{children}</th>
  );
}

export function SalesTable({ sales }: { sales: Sale[] }) {
  if (sales.length === 0) {
    return <EmptyState title="No sales in this range" description="Adjust the date range above." />;
  }
  return (
    <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
      <table className="w-full text-bodySmall">
        <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
          <tr>
            <Th>When</Th>
            <Th>Sale #</Th>
            <Th>Items</Th>
            <Th>Mechanic</Th>
            <Th>Payment</Th>
            <Th className="text-right">Total</Th>
          </tr>
        </thead>
        <tbody className="divide-y divide-light-hairline">
          {sales.map((sale) => {
            const voided = saleIsVoided(sale);
            return (
              <tr key={sale.id} className="hover:bg-light-subtle">
                <td className="px-tk-md py-tk-sm text-light-text-hint">
                  {dtFmt.format(sale.createdAt)}
                </td>
                <td className="px-tk-md py-tk-sm">
                  <Link
                    to={`/reports/sale/${sale.id}`}
                    className={cn(
                      'font-semibold tabular-nums text-light-text hover:underline',
                      voided && 'text-light-text-hint line-through',
                    )}
                  >
                    {sale.saleNumber}
                  </Link>
                  {voided ? (
                    <span className="ml-tk-sm rounded-full bg-error-light px-tk-xs py-[1px] text-[10px] font-semibold uppercase tracking-wider text-error-dark">
                      Void
                    </span>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm tabular-nums">{saleTotalItemCount(sale)}</td>
                <td className="px-tk-md py-tk-sm text-light-text-hint">
                  {sale.mechanicName ?? '—'}
                </td>
                <td className="px-tk-md py-tk-sm">
                  {paymentMethodDisplayName[sale.paymentMethod]}
                </td>
                <td
                  className={cn(
                    'px-tk-md py-tk-sm text-right font-semibold tabular-nums',
                    voided ? 'text-light-text-hint line-through' : 'text-light-text',
                  )}
                >
                  {formatMoney(saleGrandTotal(sale))}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

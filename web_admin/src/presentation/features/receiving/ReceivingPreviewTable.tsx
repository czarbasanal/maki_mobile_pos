import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import type {
  ClassifiedReceivingRow,
  ReceivingRowStatus,
} from '@/domain/receiving/classifyReceivingRows';

const BADGE: Record<ReceivingRowStatus, { label: string; cls: string }> = {
  match: { label: 'Match', cls: 'bg-light-subtle text-light-text-secondary' },
  mismatch: { label: 'Variation', cls: 'bg-warning-light text-warning-dark' },
  new: { label: 'New', cls: 'bg-success-light text-success-dark' },
  error: { label: 'Error', cls: 'bg-error-light text-error-dark' },
};

export function ReceivingPreviewTable({ rows }: { rows: ClassifiedReceivingRow[] }) {
  return (
    <div className="overflow-x-auto rounded-lg border border-light-hairline bg-light-card">
      <table className="w-full text-bodySmall">
        <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
          <tr>
            <th className="px-tk-md py-tk-sm text-left font-medium">#</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">SKU</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Name</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Cost</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Price</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Status</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-light-hairline">
          {rows.map((c) => {
            const r = c.row;
            const badge = BADGE[c.status];
            const note = r.errors[0] ?? r.warnings[0] ?? null;
            return (
              <tr key={r.rowNumber} className={cn(c.status === 'error' && 'bg-error-light/30')}>
                <td className="px-tk-md py-tk-sm tabular-nums text-light-text-hint">{r.rowNumber}</td>
                <td className="px-tk-md py-tk-sm tabular-nums">{r.autoGenerateSku ? '— (auto)' : r.sku}</td>
                <td className="px-tk-md py-tk-sm">
                  <div className="font-medium text-light-text">{r.name || '—'}</div>
                  {note ? (
                    <div className={cn('text-[12px]', c.status === 'error' ? 'text-error-dark' : 'text-light-text-hint')}>
                      {note}
                    </div>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(r.cost)}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(r.price)}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{r.quantity}</td>
                <td className="px-tk-md py-tk-sm">
                  <span className={cn('rounded-full px-tk-sm py-[1px] text-[11px] font-semibold', badge.cls)}>
                    {badge.label}
                  </span>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

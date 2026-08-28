import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { displaySku } from '@/domain/products/sku';
import { skuCellText } from '@/domain/receiving/skuPreview';
import type {
  ClassifiedReceivingRow,
  DuplicateNameResolution,
  ReceivingRowStatus,
} from '@/domain/receiving/classifyReceivingRows';

const BADGE: Record<ReceivingRowStatus, { label: string; cls: string }> = {
  match: { label: 'Match', cls: 'bg-light-subtle text-light-text-secondary' },
  mismatch: { label: 'Variation', cls: 'bg-warning-light text-warning-dark' },
  new: { label: 'New', cls: 'bg-success-light text-success-dark' },
  error: { label: 'Error', cls: 'bg-error-light text-error-dark' },
  'duplicate-name': { label: 'Duplicate name', cls: 'bg-warning-light text-warning-dark' },
};

interface ReceivingPreviewTableProps {
  rows: ClassifiedReceivingRow[];
  /** Row number → the operator's choice for a `duplicate-name` row. Rows
   *  without an entry default to "variation". */
  resolutions: ReadonlyMap<number, DuplicateNameResolution>;
  onResolve: (rowNumber: number, resolution: DuplicateNameResolution) => void;
}

export function ReceivingPreviewTable({ rows, resolutions, onResolve }: ReceivingPreviewTableProps) {
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
                <td className="px-tk-md py-tk-sm tabular-nums">{skuCellText(r.sku, r.autoGenerateSku)}</td>
                <td className="px-tk-md py-tk-sm">
                  <div className="font-medium text-light-text">{r.name || '—'}</div>
                  {note ? (
                    <div className={cn('text-[12px]', c.status === 'error' ? 'text-error-dark' : 'text-light-text-hint')}>
                      {note}
                    </div>
                  ) : null}
                  {c.status === 'duplicate-name' && c.existing ? (
                    <div className="mt-tk-xs space-y-tk-xs">
                      <div className="text-[12px] text-warning-dark">
                        Matches existing {c.existing.name} ({displaySku(c.existing.sku)})
                      </div>
                      <select
                        aria-label={`Resolve row ${r.rowNumber}`}
                        value={resolutions.get(r.rowNumber) ?? 'variation'}
                        onChange={(e) => onResolve(r.rowNumber, e.target.value as DuplicateNameResolution)}
                        className="rounded-md border border-light-border bg-light-card px-tk-sm py-[2px] text-[12px] text-light-text"
                      >
                        <option value="variation">Make variation</option>
                        <option value="new">Create as new</option>
                      </select>
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

import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import type { ClassifiedRow, RowAction } from '@/domain/products/classifyRows';

const STATUS_BADGE: Record<ClassifiedRow['status'], string> = {
  new: 'bg-success-light text-success-dark',
  existing: 'bg-light-subtle text-light-text-secondary',
  error: 'bg-error-light text-error-dark',
};

export function ImportPreviewTable({
  rows,
  actions,
  onAction,
}: {
  rows: ClassifiedRow[];
  actions: Record<number, RowAction>;
  onAction: (rowNumber: number, action: RowAction) => void;
}) {
  return (
    <div className="overflow-x-auto rounded-lg border border-light-hairline bg-light-card">
      <table className="w-full text-bodySmall">
        <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
          <tr>
            <th className="px-tk-md py-tk-sm text-left font-medium">#</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Name</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Category</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Cost</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Price</th>
            <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Unit</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Supplier</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Status</th>
            <th className="px-tk-md py-tk-sm text-left font-medium">Action</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-light-hairline">
          {rows.map((r) => {
            const p = r.parsed;
            const note = p.errors[0] ?? p.warnings[0] ?? null;
            return (
              <tr key={p.rowNumber} className={cn(r.status === 'error' && 'bg-error-light/30')}>
                <td className="px-tk-md py-tk-sm tabular-nums text-light-text-hint">{p.rowNumber}</td>
                <td className="px-tk-md py-tk-sm">
                  <div className="font-medium text-light-text">{p.name || '—'}</div>
                  {note ? (
                    <div
                      className={cn(
                        'text-[12px]',
                        r.status === 'error' ? 'text-error-dark' : 'text-light-text-hint',
                      )}
                    >
                      {note}
                    </div>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm text-light-text-secondary">{p.category ?? '—'}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">
                  {formatMoney(p.cost)}
                  <span className="ml-tk-xs text-[11px] text-light-text-hint">{p.code}</span>
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(p.price)}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{p.quantity}</td>
                <td className="px-tk-md py-tk-sm text-light-text-secondary">{p.unit}</td>
                <td className="px-tk-md py-tk-sm text-light-text-secondary">
                  {p.supplierName ?? '—'}
                  {p.supplierName && !r.supplierMatched ? (
                    <span className="ml-tk-xs text-[11px] text-warning-dark">new</span>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm">
                  <span
                    className={cn(
                      'rounded-full px-tk-sm py-[1px] text-[11px] font-semibold capitalize',
                      STATUS_BADGE[r.status],
                    )}
                  >
                    {r.status}
                  </span>
                </td>
                <td className="px-tk-md py-tk-sm">
                  <select
                    className="rounded-md border border-light-border bg-light-card px-tk-sm py-[4px] text-bodySmall text-light-text outline-none focus:border-light-text disabled:opacity-50"
                    value={actions[p.rowNumber] ?? r.defaultAction}
                    disabled={r.status === 'error'}
                    onChange={(e) => onAction(p.rowNumber, e.target.value as RowAction)}
                  >
                    {r.status === 'new' ? <option value="insert">Insert</option> : null}
                    {r.status === 'existing' ? <option value="update">Update</option> : null}
                    {r.status === 'existing' ? <option value="insert">Insert as new</option> : null}
                    <option value="skip">Skip</option>
                  </select>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

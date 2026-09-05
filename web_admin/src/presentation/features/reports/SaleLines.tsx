// The lines under a sale, shown in the sales table's expansion band: items
// (name + option, SKU with copy, qty, unit price, line net), then labor and
// fee lines, the order discount when there is one, and a way into the sale.
// Mirrors the sale-detail items rows so the two never disagree on a line.
import { Link } from 'react-router-dom';
import {
  feeLineDisplayLabel,
  saleIsPercentageDiscount,
  saleItemHasOption,
  saleItemNet,
  saleItemOptionSetsCaption,
  saleTotalDiscount,
  type Sale,
} from '@/domain/entities';
import { displaySku } from '@/domain/products/sku';
import { formatMoney } from '@/core/utils/money';
import { CopyButton } from '@/presentation/components/ui/CopyButton';

function Line({ label, sub, qty, unit, total, dim = false }: {
  label: React.ReactNode; sub?: React.ReactNode; qty?: number; unit?: number; total: number; dim?: boolean;
}) {
  return (
    <div className="grid grid-cols-[minmax(0,1fr)_56px_104px_112px] items-baseline gap-3 py-[7px]">
      <div className="min-w-0">
        <div className={dim ? 'text-[12px] text-ink-2' : 'text-[12px] font-medium text-ink'}>{label}</div>
        {sub ? <div className="text-[10.5px] text-ink-3">{sub}</div> : null}
      </div>
      <span className="text-right font-mono text-[12px] text-ink-2">{qty ?? ''}</span>
      <span className="text-right font-mono text-[12px] text-ink-2">{unit !== undefined ? formatMoney(unit) : ''}</span>
      <span className="text-right font-mono text-[12px] font-semibold text-ink">{formatMoney(total)}</span>
    </div>
  );
}

export function SaleLines({ sale }: { sale: Sale }) {
  const isPct = saleIsPercentageDiscount(sale);
  const discount = saleTotalDiscount(sale);
  return (
    <div data-testid={`sale-lines-${sale.id}`} className="flex flex-col">
      <div className="grid grid-cols-[minmax(0,1fr)_56px_104px_112px] gap-3 pb-1 text-micro-caps uppercase text-ink-3">
        <span>Item</span><span className="text-right">Qty</span><span className="text-right">Unit</span><span className="text-right">Line</span>
      </div>
      <div className="divide-y divide-line-2">
        {sale.items.map((it) => (
          <Line
            key={it.id}
            label={
              <>
                {it.name}
                {saleItemHasOption(it) ? <span className="text-ink-2"> · {it.optionLabel}</span> : null}
              </>
            }
            sub={
              <span className="flex items-center gap-[5px] whitespace-nowrap font-mono">
                {displaySku(it.sku)}
                <CopyButton value={it.sku} label="SKU" />
                {saleItemOptionSetsCaption(it) ? <span className="font-sans">· {saleItemOptionSetsCaption(it)}</span> : null}
              </span>
            }
            qty={it.quantity}
            unit={it.unitPrice}
            total={saleItemNet(it, isPct)}
          />
        ))}
        {sale.laborLines.map((l) => (
          <Line key={l.id} label={l.description} sub="Labor" total={l.fee} dim />
        ))}
        {sale.feeLines.map((f) => (
          <Line key={f.id} label={feeLineDisplayLabel(f)} sub="Shop fee" total={f.amount} dim />
        ))}
        {discount > 0 ? <Line label="Discount" total={-discount} dim /> : null}
      </div>
      <div className="flex justify-end pt-2">
        <Link to={`/reports/sale/${sale.id}`} className="text-[11.5px] font-medium text-ink-2 hover:text-ink">
          Open sale →
        </Link>
      </div>
    </div>
  );
}

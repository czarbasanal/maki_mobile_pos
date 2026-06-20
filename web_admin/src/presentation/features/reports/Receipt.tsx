import {
  saleEffectiveTenders,
  saleGrandTotal,
  saleIsPercentageDiscount,
  saleIsVoided,
  saleItemNet,
  saleLaborSubtotal,
  salePartsSubtotal,
  saleTotalDiscount,
} from '@/domain/entities';
import type { Sale } from '@/domain/entities';
import { paymentMethodDisplayName, realTenderMethods } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';

const RECEIPT_STORE_NAME = 'MAKI Mobile POS';
const dtFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short' });

export function Receipt({ sale }: { sale: Sale }) {
  const isPct = saleIsPercentageDiscount(sale);
  const tenders = saleEffectiveTenders(sale);
  const voided = saleIsVoided(sale);

  return (
    <div className="mx-auto max-w-[320px] p-tk-md font-mono text-[12px] text-light-text">
      <div className="text-center">
        <div className="text-[14px] font-bold">{RECEIPT_STORE_NAME}</div>
        <div>{sale.saleNumber}</div>
        <div>{dtFmt.format(sale.createdAt)}</div>
        <div>Cashier: {sale.cashierName}</div>
        {sale.mechanicName ? <div>Mechanic: {sale.mechanicName}</div> : null}
      </div>

      {voided ? (
        <div className="my-tk-sm text-center font-bold">
          *** VOIDED ***{sale.voidReason ? ` (${sale.voidReason})` : ''}
        </div>
      ) : null}

      <Divider />

      {sale.items.map((it) => (
        <div key={it.id} className="flex justify-between gap-tk-sm">
          <span className="min-w-0 truncate">
            {it.name}{' '}
            <span className="text-[10px] text-light-text-hint">
              {it.quantity}×{formatMoney(it.unitPrice)}
            </span>
          </span>
          <span className="tabular-nums">{formatMoney(saleItemNet(it, isPct))}</span>
        </div>
      ))}
      {sale.laborLines.map((l) => (
        <div key={l.id} className="flex justify-between gap-tk-sm">
          <span className="min-w-0 truncate">🔧 {l.description || 'Service'}</span>
          <span className="tabular-nums">{formatMoney(l.fee)}</span>
        </div>
      ))}

      <Divider />

      <Line label="Subtotal" value={formatMoney(salePartsSubtotal(sale))} />
      <Line label="Discount" value={`-${formatMoney(saleTotalDiscount(sale))}`} />
      <Line label="Labor" value={formatMoney(saleLaborSubtotal(sale))} />
      <Line label="TOTAL" value={formatMoney(saleGrandTotal(sale))} bold />

      <Divider />

      {realTenderMethods
        .filter((m) => (tenders[m] ?? 0) > 0)
        .map((m) => (
          <Line key={m} label={paymentMethodDisplayName[m]} value={formatMoney(tenders[m] ?? 0)} />
        ))}
      <Line label="Amount received" value={formatMoney(sale.amountReceived)} />
      <Line label="Change" value={formatMoney(sale.changeGiven)} />

      <div className="mt-tk-md text-center text-[11px] text-light-text-secondary">Thank you!</div>
    </div>
  );
}

function Divider() {
  return <div className="my-tk-sm border-t border-dashed border-light-border" />;
}

function Line({ label, value, bold }: { label: string; value: string; bold?: boolean }) {
  return (
    <div className={`flex justify-between ${bold ? 'font-bold' : ''}`}>
      <span>{label}</span>
      <span className="tabular-nums">{value}</span>
    </div>
  );
}

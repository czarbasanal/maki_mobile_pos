import { cn } from '@/core/utils/cn';
import { formatMoney } from '@/core/utils/money';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import type { PaymentMode } from '@/domain/sales/payment';
import type { usePaymentDraft } from '@/presentation/hooks/usePaymentDraft';

type Pay = ReturnType<typeof usePaymentDraft>;

const MODES: { mode: PaymentMode; label: string }[] = [
  { mode: 'cash', label: 'Cash' },
  { mode: 'gcash', label: 'GCash' },
  { mode: 'maya', label: 'Maya' },
  { mode: 'mixed', label: 'Mixed' },
  { mode: 'salmon', label: 'Salmon' },
];

export function PaymentSection({ pay, grandTotal }: { pay: Pay; grandTotal: number }) {
  return (
    <div className="space-y-tk-sm">
      <div className="flex flex-wrap gap-tk-xs">
        {MODES.map(({ mode, label }) => (
          <button
            key={mode}
            type="button"
            onClick={() => pay.setMode(mode)}
            className={cn(
              'rounded-full border px-tk-md py-[6px] text-ctl-sm',
              pay.mode === mode
                ? 'border-accent-line bg-accent text-accent-ink'
                : 'border-line bg-surface text-ink-2 hover:bg-surface-2',
            )}
          >
            {label}
          </button>
        ))}
      </div>

      {pay.mode === 'cash' ? (
        <>
          <AmountInput label="Cash received" value={pay.cashText} onChange={pay.setCashText} />
          <Row label="Change" value={formatMoney(pay.changeGiven)} />
        </>
      ) : null}

      {pay.mode === 'gcash' || pay.mode === 'maya' ? (
        <p className="text-cell text-ink-2">
          Paid in full via {pay.mode === 'gcash' ? 'GCash' : 'Maya'} — {formatMoney(grandTotal)}
        </p>
      ) : null}

      {pay.mode === 'mixed' ? (
        <div className="space-y-tk-sm">
          <SubSelector
            label="Digital"
            options={[
              { value: 'gcash', label: 'GCash' },
              { value: 'maya', label: 'Maya' },
            ]}
            value={pay.digitalMethod}
            onChange={(v) => pay.setDigitalMethod(v as 'gcash' | 'maya')}
          />
          <AmountInput label="Digital amount" value={pay.splitText} onChange={pay.setSplitText} />
          <Row
            label="Cash portion"
            value={formatMoney(Math.max(0, pay.tenders[PaymentMethod.cash] ?? 0))}
          />
        </div>
      ) : null}

      {pay.mode === 'salmon' ? (
        <div className="space-y-tk-sm">
          <SubSelector
            label="Downpayment via"
            options={[
              { value: 'cash', label: 'Cash' },
              { value: 'gcash', label: 'GCash' },
              { value: 'maya', label: 'Maya' },
            ]}
            value={pay.dpMethod}
            onChange={(v) => pay.setDpMethod(v as 'cash' | 'gcash' | 'maya')}
          />
          <AmountInput label="Downpayment" value={pay.splitText} onChange={pay.setSplitText} />
          <Row
            label="Salmon balance (receivable)"
            value={formatMoney(Math.max(0, pay.tenders[PaymentMethod.salmon] ?? 0))}
          />
        </div>
      ) : null}

      {pay.error ? <p className="text-ctl-sm text-neg">{pay.error}</p> : null}
    </div>
  );
}

function AmountInput({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <label className="block space-y-tk-xs">
      <span className="text-cell font-medium text-ink">{label}</span>
      <input
        type="number"
        min={0}
        step="0.01"
        inputMode="decimal"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-field border border-line bg-surface px-tk-md py-[10px] text-cell"
      />
    </label>
  );
}

function SubSelector({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: { value: string; label: string }[];
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="flex items-center gap-tk-sm text-ctl-sm text-ink-2">
      <span>{label}</span>
      <div className="flex gap-tk-xs">
        {options.map((o) => (
          <button
            key={o.value}
            type="button"
            onClick={() => onChange(o.value)}
            className={cn(
              'rounded-ctl border px-tk-sm py-[4px]',
              value === o.value
                ? 'border-accent-text bg-accent-soft text-accent-text'
                : 'border-line bg-surface hover:bg-surface-2',
            )}
          >
            {o.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between text-cell">
      <span className="text-ink-3">{label}</span>
      <span className="font-mono tabular-nums text-ink">{value}</span>
    </div>
  );
}

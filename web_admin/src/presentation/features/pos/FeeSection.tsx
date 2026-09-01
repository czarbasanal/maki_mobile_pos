// Shop-fee entry on the cart — inline rows mirroring LaborSection: pick a
// fee from the catalog dropdown, the amount field sits right beside it
// (prefilled from the fee's defaultAmount), "Charge Item" grows an inline
// description. Unfinished rows never reach a sale (chargeableFeeLines).
import { useState } from 'react';
import { PlusIcon, XMarkIcon } from '@heroicons/react/24/outline';
import type { CartStore } from '@/presentation/stores/cartStore';
import { useShopFees } from '@/presentation/hooks/useShopFees';
import { CHARGE_ITEM_FEE_NAME, type FeeLine, type ShopFee } from '@/domain/entities';
import { IconButton } from '@/presentation/components/ui/IconButton';
import { Button } from '@/presentation/components/ui/Button';

export function FeeSection({ store }: { store: CartStore }) {
  const feeLines = store((s) => s.feeLines);
  const addFeeLine = store((s) => s.addFeeLine);
  const setFeeLine = store((s) => s.setFeeLine);
  const removeFeeLine = store((s) => s.removeFeeLine);
  const { data: fees } = useShopFees();
  const catalog = fees ?? [];

  return (
    <div className="space-y-tk-sm border-t border-line-2 px-[18px] py-3">
      <div className="flex items-center justify-between">
        <span className="text-cell font-semibold text-ink">Shop fees</span>
        <Button size="sm" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={addFeeLine}>
          Add fee
        </Button>
      </div>

      {feeLines.map((line) => (
        <FeeRow
          key={line.id}
          line={line}
          catalog={catalog}
          onChange={setFeeLine}
          onRemove={removeFeeLine}
        />
      ))}
      {feeLines.length > 0 && catalog.length === 0 ? (
        <p className="text-micro text-ink-3">
          No shop fees configured. Add one in Settings on the register phone first.
        </p>
      ) : null}
    </div>
  );
}

function FeeRow({
  line,
  catalog,
  onChange,
  onRemove,
}: {
  line: FeeLine;
  catalog: ShopFee[];
  onChange: (id: string, patch: Partial<Pick<FeeLine, 'name' | 'amount' | 'description'>>) => void;
  onRemove: (id: string) => void;
}) {
  // Amount is string-backed locally so decimals type cleanly; the store
  // keeps the parsed number for the totals (same pattern as LaborRow).
  const [amountText, setAmountText] = useState(line.amount ? String(line.amount) : '');

  const isChargeItem = line.name === CHARGE_ITEM_FEE_NAME;
  // A carried fee (resumed mobile JO, archived catalog entry) stays pickable.
  const names = catalog.map((f) => f.name);
  const options = line.name && !names.includes(line.name) ? [line.name, ...names] : names;

  const pick = (name: string) => {
    const fee = catalog.find((f) => f.name === name);
    const patch: Partial<Pick<FeeLine, 'name' | 'amount' | 'description'>> = {
      name,
      description: null,
    };
    // Prefill the default amount only while the row hasn't been priced yet.
    if (line.amount <= 0 && fee?.defaultAmount && fee.defaultAmount > 0) {
      patch.amount = fee.defaultAmount;
      setAmountText(fee.defaultAmount.toFixed(2));
    }
    onChange(line.id, patch);
  };

  const needsAmount = line.name.trim() !== '' && line.amount <= 0;
  const needsDescription = isChargeItem && (line.description ?? '').trim() === '';

  return (
    <div className="space-y-tk-xs">
      <div className="flex items-center gap-tk-sm">
        <select
          aria-label="Shop fee"
          value={line.name || ''}
          onChange={(e) => pick(e.target.value)}
          className="min-w-0 flex-1 rounded-field border border-line bg-surface-2 px-2.5 py-1.5 text-ctl-sm text-ink outline-none"
        >
          <option value="" disabled>
            Select fee…
          </option>
          {options.map((name) => (
            <option key={name} value={name}>
              {name}
            </option>
          ))}
        </select>
        <input
          type="text"
          inputMode="decimal"
          value={amountText}
          disabled={line.name.trim() === ''}
          onChange={(e) => {
            setAmountText(e.target.value);
            onChange(line.id, { amount: parseFloat(e.target.value) || 0 });
          }}
          placeholder="₱"
          className="w-[64px] rounded-field border border-line bg-surface-2 px-2 py-1.5 text-right font-mono text-ctl-sm text-ink outline-none placeholder:text-ink-3 disabled:opacity-50"
        />
        <IconButton title="Remove fee" tone="danger" onClick={() => onRemove(line.id)}>
          <XMarkIcon className="h-3.5 w-3.5" />
        </IconButton>
      </div>
      {isChargeItem ? (
        <input
          type="text"
          value={line.description ?? ''}
          onChange={(e) => onChange(line.id, { description: e.target.value })}
          placeholder="What's being charged?"
          className="w-full rounded-field border border-line bg-surface-2 px-2.5 py-1.5 text-ctl-sm text-ink outline-none placeholder:text-ink-3"
        />
      ) : null}
      {needsAmount ? (
        <p className="text-micro text-accent-text">Enter an amount to include this fee.</p>
      ) : null}
      {needsDescription && !needsAmount ? (
        <p className="text-micro text-accent-text">
          Describe what's being charged to include this fee.
        </p>
      ) : null}
    </div>
  );
}

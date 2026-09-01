// Shop-fee entry on the cart (mobile fee_section.dart parity): pick a fee
// from the admin-managed catalog, confirm/edit the amount (prefilled from
// defaultAmount), and — for "Charge Item" only — describe what's charged.
// Fees are full price, never discounted, zero cost.
import { useState } from 'react';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import type { CartStore } from '@/presentation/stores/cartStore';
import { useShopFees } from '@/presentation/hooks/useShopFees';
import { Dialog } from '@/presentation/components/common/Dialog';
import { CHARGE_ITEM_FEE_NAME, feeLineDisplayLabel, type FeeLine, type ShopFee } from '@/domain/entities';
import { formatMoney } from '@/core/utils/money';

export function FeeSection({ store }: { store: CartStore }) {
  const feeLines = store((s) => s.feeLines);
  const addFeeLine = store((s) => s.addFeeLine);
  const setFeeAmount = store((s) => s.setFeeAmount);
  const removeFeeLine = store((s) => s.removeFeeLine);
  const [pickerOpen, setPickerOpen] = useState(false);

  return (
    <div className="space-y-tk-sm border-t border-light-hairline px-tk-md py-tk-sm">
      <div className="flex items-center justify-between">
        <span className="text-bodySmall font-medium text-light-text">Shop fees</span>
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-[4px] text-[12px] text-light-text-secondary hover:bg-light-subtle"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add fee
        </button>
      </div>

      {feeLines.map((line) => (
        <FeeRow key={line.id} line={line} onAmount={setFeeAmount} onRemove={removeFeeLine} />
      ))}

      <AddFeeDialog
        open={pickerOpen}
        onClose={() => setPickerOpen(false)}
        onAdd={(line) => {
          addFeeLine(line);
          setPickerOpen(false);
        }}
      />
    </div>
  );
}

function FeeRow({
  line,
  onAmount,
  onRemove,
}: {
  line: FeeLine;
  onAmount: (id: string, amount: number) => void;
  onRemove: (id: string) => void;
}) {
  const [amountText, setAmountText] = useState(line.amount ? String(line.amount) : '');
  return (
    <div className="flex items-center gap-tk-sm">
      <span className="min-w-0 flex-1 truncate text-[12px] text-light-text">
        {feeLineDisplayLabel(line)}
      </span>
      <input
        type="text"
        inputMode="decimal"
        value={amountText}
        onChange={(e) => {
          setAmountText(e.target.value);
          onAmount(line.id, parseFloat(e.target.value) || 0);
        }}
        className="w-24 rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-right text-[12px]"
      />
      <button
        type="button"
        aria-label="Remove fee"
        onClick={() => onRemove(line.id)}
        className="rounded-md p-tk-xs text-light-text-hint hover:bg-light-subtle hover:text-error"
      >
        <TrashIcon className="h-4 w-4" />
      </button>
    </div>
  );
}

function AddFeeDialog({
  open,
  onClose,
  onAdd,
}: {
  open: boolean;
  onClose: () => void;
  onAdd: (line: FeeLine) => void;
}) {
  const { data: fees } = useShopFees();
  const [selected, setSelected] = useState<ShopFee | null>(null);
  const [amountText, setAmountText] = useState('');
  const [description, setDescription] = useState('');

  const requiresDescription = selected?.name === CHARGE_ITEM_FEE_NAME;
  const amount = parseFloat(amountText);
  const valid = amount > 0 && (!requiresDescription || description.trim() !== '');

  const reset = () => {
    setSelected(null);
    setAmountText('');
    setDescription('');
  };

  const pick = (fee: ShopFee) => {
    setSelected(fee);
    setAmountText(fee.defaultAmount && fee.defaultAmount > 0 ? fee.defaultAmount.toFixed(2) : '');
    setDescription('');
  };

  const submit = () => {
    if (!selected || !valid) return;
    onAdd({
      id: crypto.randomUUID(),
      name: selected.name,
      amount,
      description: requiresDescription ? description.trim() : null,
    });
    reset();
  };

  return (
    <Dialog
      open={open}
      onClose={() => {
        reset();
        onClose();
      }}
      title={selected ? selected.name : 'Add shop fee'}
    >
      {selected === null ? (
        (fees ?? []).length === 0 ? (
          <p className="text-bodySmall text-light-text-secondary">
            No shop fees configured. Add one in Settings on the register phone first.
          </p>
        ) : (
          <div className="space-y-tk-xs">
            {(fees ?? []).map((fee) => (
              <button
                key={fee.id}
                type="button"
                onClick={() => pick(fee)}
                className="flex w-full items-center justify-between rounded-md border border-light-border px-tk-md py-tk-sm text-left text-bodySmall hover:bg-light-subtle"
              >
                <span>{fee.name}</span>
                {fee.defaultAmount ? (
                  <span className="text-light-text-secondary">{formatMoney(fee.defaultAmount)}</span>
                ) : null}
              </button>
            ))}
          </div>
        )
      ) : (
        <div className="space-y-tk-sm">
          <label className="block text-[12px] text-light-text-secondary">
            Amount
            <input
              type="text"
              inputMode="decimal"
              value={amountText}
              onChange={(e) => setAmountText(e.target.value)}
              autoFocus
              className="mt-tk-xs w-full rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px] text-light-text"
            />
          </label>
          {requiresDescription ? (
            <label className="block text-[12px] text-light-text-secondary">
              Description
              <input
                type="text"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="What's being charged?"
                className="mt-tk-xs w-full rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px] text-light-text"
              />
            </label>
          ) : null}
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setSelected(null)}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text-secondary hover:bg-light-subtle"
            >
              Back
            </button>
            <button
              type="button"
              disabled={!valid}
              onClick={submit}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
            >
              Add
            </button>
          </div>
        </div>
      )}
    </Dialog>
  );
}

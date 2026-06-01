import { useState } from 'react';
import { Dialog } from '@/presentation/components/common/Dialog';
import { Spinner } from '@/presentation/components/common/LoadingView';
import { useAdjustStock, useSetStock } from '@/presentation/hooks/useProductMutations';
import { resolveStockChange, type StockMode } from '@/domain/products/resolveStockChange';
import type { Product } from '@/domain/entities';
import { cn } from '@/core/utils/cn';

const MODES: { value: StockMode; label: string }[] = [
  { value: 'add', label: 'Add' },
  { value: 'remove', label: 'Remove' },
  { value: 'set', label: 'Set to' },
];

export function AdjustStockDialog({
  product,
  open,
  onClose,
}: {
  product: Product;
  open: boolean;
  onClose: () => void;
}) {
  const [mode, setMode] = useState<StockMode>('add');
  const [qtyText, setQtyText] = useState('');
  const adjust = useAdjustStock();
  const setStock = useSetStock();
  const busy = adjust.isPending || setStock.isPending;

  const qty = Number(qtyText);
  const numericOk = qtyText.trim() !== '' && Number.isInteger(qty) && qty >= 0;

  let err: string | null = null;
  if (qtyText.trim() !== '') {
    if (!Number.isInteger(qty) || qty < 0) err = 'Enter a whole number ≥ 0';
    else if ((mode === 'add' || mode === 'remove') && qty <= 0) err = 'Quantity must be greater than 0';
    else if (mode === 'remove' && qty > product.quantity) err = 'Cannot remove more than current stock';
  }

  const showPreview = numericOk && !err;
  const newQty = showPreview ? resolveStockChange(mode, product.quantity, qty) : product.quantity;
  const previewColor =
    newQty <= 0 ? 'text-error-dark' : newQty <= product.reorderLevel ? 'text-warning-dark' : 'text-success-dark';
  const canApply = showPreview && !busy;

  const apply = async () => {
    if (mode === 'set') await setStock.mutateAsync({ id: product.id, quantity: qty });
    else await adjust.mutateAsync({ id: product.id, delta: mode === 'add' ? qty : -qty });
    setQtyText('');
    onClose();
  };

  return (
    <Dialog
      open={open}
      onClose={() => {
        if (!busy) {
          setQtyText('');
          onClose();
        }
      }}
      title="Adjust stock"
      dismissable={!busy}
    >
      <div className="space-y-tk-md">
        <div className="inline-flex rounded-md border border-light-hairline p-[2px]">
          {MODES.map((m) => (
            <button
              key={m.value}
              type="button"
              onClick={() => setMode(m.value)}
              className={cn(
                'rounded px-tk-md py-[4px] text-bodySmall transition-colors',
                mode === m.value
                  ? 'bg-light-subtle font-semibold text-light-text'
                  : 'text-light-text-secondary hover:text-light-text',
              )}
            >
              {m.label}
            </button>
          ))}
        </div>

        <div>
          <label className="mb-tk-xs block text-bodySmall text-light-text-secondary">Quantity</label>
          <input
            type="number"
            inputMode="numeric"
            value={qtyText}
            onChange={(e) => setQtyText(e.target.value)}
            autoFocus
            className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
          />
          {err ? <p className="mt-tk-xs text-[12px] text-error">{err}</p> : null}
        </div>

        <p className="text-bodySmall text-light-text-secondary">
          New quantity:{' '}
          <span className={cn('font-semibold', showPreview ? previewColor : 'text-light-text-hint')}>
            {showPreview ? newQty : '—'}
          </span>{' '}
          {product.unit}
        </p>

        <div className="flex justify-end gap-tk-sm pt-tk-sm">
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              setQtyText('');
              onClose();
            }}
            className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={!canApply}
            onClick={apply}
            className="inline-flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
          >
            {busy ? <Spinner className="h-3.5 w-3.5" /> : null} Apply
          </button>
        </div>
      </div>
    </Dialog>
  );
}

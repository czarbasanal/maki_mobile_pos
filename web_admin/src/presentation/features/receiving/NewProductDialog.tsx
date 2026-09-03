// Full-field "new product" form for the receiving entry page, in a modal —
// replacing an 8-field inline grid that was too cramped to read. Mirrors the
// New Product page's fields except the image (a draft receiving persists plain
// data to Firestore, and a pending image file would silently vanish on
// save-as-draft; photos are added from the product drawer after receiving).
//
// Auto-SKU is the category-driven kind, matching the New Product page: picking
// a coded category peeks the next sequence for a PREVIEW, and the real claim
// happens inside the receive transaction (executeReceivePlan scans forward
// under the category code) — the retired name-based generator is not used.
// Nothing is created here: the dialog only queues a pendingNewProduct line;
// the product exists once the receiving is completed.
import { useEffect, useMemo, useState } from 'react';
import { XMarkIcon } from '@heroicons/react/24/outline';
import { Dialog } from '@/presentation/components/common/Dialog';
import { SellingOptionsEditor } from '@/presentation/features/inventory/SellingOptionsEditor';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { useAuthStore } from '@/presentation/stores/authStore';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { UserRole } from '@/domain/enums';
import { composeAutoSku, matchesAutoPattern } from '@/domain/products/sku';
import { PENDING_SKU_LABEL } from '@/domain/receiving/skuPreview';
import { validateSellingOptions } from '@/domain/products/sellingOptions';
import type { Category, SellingOption } from '@/domain/entities';
import type { NewProductSpec } from './useReceivingEntry';

const inputCls =
  'w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text';

interface NewProductDialogProps {
  open: boolean;
  onClose: () => void;
  /** Queues (or, in edit mode, replaces) the line; creation happens when the
   *  receiving completes. */
  onAdd: (spec: NewProductSpec) => void;
  /** Edit mode: prefill from an already-queued line's spec. */
  initial?: NewProductSpec | null;
}

export function NewProductDialog({ open, onClose, onAdd, initial = null }: NewProductDialogProps) {
  const { data: productCats } = useActiveCategories(CategoryKind.product);
  const { data: units } = useActiveCategories(CategoryKind.unit);
  const isAdmin = useAuthStore((s) => s.user?.role === UserRole.admin);

  const [name, setName] = useState('');
  const [sku, setSku] = useState('');
  const [autoSku, setAutoSku] = useState(true);
  const [skuHint, setSkuHint] = useState<string | null>('Pick a category to generate the SKU.');
  const [category, setCategory] = useState<string | null>(null);
  const [unit, setUnit] = useState('pcs');
  const [cost, setCost] = useState('');
  const [price, setPrice] = useState('');
  const [quantity, setQuantity] = useState('');
  const [reorderLevel, setReorderLevel] = useState('');
  const [barcodes, setBarcodes] = useState<string[]>([]);
  const [barcodeDraft, setBarcodeDraft] = useState('');
  const [notes, setNotes] = useState('');
  const [sellingOptions, setSellingOptions] = useState<SellingOption[]>([]);
  const [error, setError] = useState<string | null>(null);

  const categoryEntityForName = (n: string): Category | undefined =>
    (productCats ?? []).find((c) => c.name === n);

  /** Seeds the SKU for a coded category; anything else leaves the field EMPTY
   *  with a hint — never the old name-based format.
   *
   *  The seed is sequence 1 and is NOT shown. The receive transaction scans
   *  from max(seed, registry.nextSequence), so the seed is only a floor — it
   *  was never the SKU. Peeking the registry here produced a number that
   *  looked authoritative and was the same for every row added before saving,
   *  which is exactly how three new products came to display one code. */
  const applyCategoryForSku = (cat: Category | undefined, autoOn: boolean) => {
    if (!autoOn) return;
    const code = cat?.code;
    if (code === undefined) {
      setSku('');
      setSkuHint(
        cat === undefined
          ? 'Pick a category to generate the SKU.'
          : 'This category has no code — pick another, or turn off auto-generate and type a SKU.',
      );
      return;
    }
    setSku(composeAutoSku(code, 1));
    setSkuHint('The SKU is assigned when the receiving is saved.');
  };

  // Edit mode: hydrate every field from the queued spec when opening. Keyed
  // on `open` so a second edit of the same line re-hydrates fresh state.
  useEffect(() => {
    if (!open || !initial) return;
    setName(initial.name);
    setSku(initial.sku);
    setAutoSku(initial.autoGenerateSku);
    setSkuHint(
      initial.autoGenerateSku && initial.autoSkuCategoryCode != null
        ? 'The SKU is assigned when the receiving is saved.'
        : null,
    );
    setCategory(initial.category);
    setUnit(initial.unit);
    setCost(String(initial.cost));
    setPrice(String(initial.price));
    setQuantity(String(initial.quantity));
    setReorderLevel(initial.reorderLevel ? String(initial.reorderLevel) : '');
    setBarcodes(initial.barcodes);
    setBarcodeDraft('');
    setNotes(initial.notes ?? '');
    setSellingOptions(initial.sellingOptions);
    setError(null);
  }, [open, initial]);

  const sellingOptionsError = useMemo(
    () => validateSellingOptions(sellingOptions),
    [sellingOptions],
  );

  const commitBarcode = () => {
    const code = barcodeDraft.trim();
    if (!code) return;
    if (!barcodes.includes(code)) setBarcodes((b) => [...b, code]);
    setBarcodeDraft('');
  };

  const reset = () => {
    setName(''); setSku(''); setAutoSku(true);
    setSkuHint('Pick a category to generate the SKU.');
    setCategory(null); setUnit('pcs'); setCost(''); setPrice('');
    setQuantity(''); setReorderLevel(''); setBarcodes([]); setBarcodeDraft('');
    setNotes(''); setSellingOptions([]); setError(null);
  };

  const submit = () => {
    const n = name.trim();
    const s = sku.trim();
    const q = Number(quantity);
    const c = Number(cost);
    const p = Number(price);
    if (!n) return setError('Name is required.');
    if (!s) {
      return setError(
        autoSku
          ? 'Pick a coded category to generate the SKU, or turn off auto-generate and type one.'
          : 'SKU is required.',
      );
    }
    if (!Number.isFinite(c) || c < 0) return setError('Cost must be 0 or more.');
    if (!Number.isFinite(p) || p < 0) return setError('Price must be 0 or more.');
    if (!Number.isFinite(q) || q <= 0) return setError('Quantity must be more than 0.');
    if (sellingOptionsError) return setError(sellingOptionsError);

    const code = categoryEntityForName(category ?? '')?.code;
    onAdd({
      name: n,
      sku: s,
      autoGenerateSku: autoSku,
      // Only a preview that still matches the code's pattern is re-scannable
      // at receive time; a hand-edited value is treated as literal.
      autoSkuCategoryCode:
        autoSku && code !== undefined && matchesAutoPattern(s, code) ? code : null,
      category,
      unit,
      cost: c,
      price: p,
      quantity: q,
      // Unset → 1 (user call): a brand-new part should never be invisible
      // to the low-stock and buying-list engines. An explicit 0 is kept.
      reorderLevel: reorderLevel.trim() === '' ? 1 : Number(reorderLevel) || 0,
      barcodes,
      notes: notes.trim() || null,
      sellingOptions,
    });
    reset();
    onClose();
  };

  return (
    <Dialog
      open={open}
      onClose={() => { reset(); onClose(); }}
      title={initial ? 'Edit product' : 'New product'}
      description="Added to inventory when this receiving is completed. Photo can be added afterward from the product page."
      className="max-w-2xl"
    >
      <div className="max-h-[70vh] space-y-tk-md overflow-y-auto pr-tk-xs">
        {error ? (
          <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
            {error}
          </p>
        ) : null}

        <Field label="Name">
          <input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} />
        </Field>

        <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
          <Field label="Category">
            <select
              className={inputCls}
              aria-label="Category"
              value={category ?? ''}
              onChange={(e) => {
                const v = e.target.value || null;
                setCategory(v);
                applyCategoryForSku(v ? categoryEntityForName(v) : undefined, autoSku);
              }}
            >
              <option value="">—</option>
              {(productCats ?? []).map((c) => (
                <option key={c.id} value={c.name}>{c.name}</option>
              ))}
            </select>
          </Field>
          <Field label="SKU">
            <input
              className={inputCls}
              aria-label="SKU"
              /* An auto row has no SKU yet — showing the seed would be showing
                 a code that is not the one the product ends up with. */
              value={autoSku && sku ? PENDING_SKU_LABEL : sku}
              disabled={autoSku}
              onChange={(e) => setSku(e.target.value)}
            />
            <label className="mt-tk-xs flex items-center gap-tk-xs text-bodySmall text-light-text">
              <input
                type="checkbox"
                checked={autoSku}
                onChange={(e) => {
                  const on = e.target.checked;
                  setAutoSku(on);
                  if (on) {
                    applyCategoryForSku(categoryEntityForName(category ?? ''), true);
                  } else {
                    setSkuHint(null);
                  }
                }}
              />
              Auto-generate SKU from category
            </label>
            {skuHint ? (
              <p className="mt-tk-xs text-[12px] text-light-text-hint">{skuHint}</p>
            ) : null}
          </Field>
          <Field label="Unit">
            <select className={inputCls} aria-label="Unit" value={unit}
              onChange={(e) => setUnit(e.target.value)}>
              {(units ?? []).map((u) => <option key={u.id} value={u.name}>{u.name}</option>)}
              {(units ?? []).every((u) => u.name !== unit) ? (
                <option value={unit}>{unit}</option>
              ) : null}
            </select>
          </Field>
          <Field label="Reorder level">
            <input type="number" className={inputCls} aria-label="Reorder level"
              placeholder="1"
              value={reorderLevel} onChange={(e) => setReorderLevel(e.target.value)} />
          </Field>
          <Field label="Cost">
            <input type="number" step="0.01" className={inputCls} aria-label="Cost"
              value={cost} onChange={(e) => setCost(e.target.value)} />
          </Field>
          <Field label="Price">
            <input type="number" step="0.01" className={inputCls} aria-label="Price"
              value={price} onChange={(e) => setPrice(e.target.value)} />
          </Field>
          <Field label="Quantity received">
            <input type="number" className={inputCls} aria-label="Quantity received"
              value={quantity} onChange={(e) => setQuantity(e.target.value)} />
          </Field>
        </div>

        <Field label="Barcodes">
          <div className="flex gap-tk-sm">
            <input
              className={inputCls}
              aria-label="Add barcode"
              value={barcodeDraft}
              onChange={(e) => setBarcodeDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') { e.preventDefault(); commitBarcode(); }
              }}
              placeholder="Scan or type, then Enter"
            />
            <button type="button" onClick={commitBarcode}
              className="shrink-0 rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
              Add
            </button>
          </div>
          {barcodes.length > 0 ? (
            <div className="mt-tk-sm flex flex-wrap gap-tk-xs">
              {barcodes.map((b) => (
                <span key={b}
                  className="inline-flex items-center gap-tk-xs rounded-full bg-light-subtle px-tk-sm py-[2px] font-mono text-[12px] text-light-text">
                  {b}
                  <button type="button" aria-label={`Remove barcode ${b}`}
                    onClick={() => setBarcodes((list) => list.filter((x) => x !== b))}
                    className="text-light-text-hint hover:text-error">
                    <XMarkIcon className="h-3 w-3" />
                  </button>
                </span>
              ))}
            </div>
          ) : null}
        </Field>

        {isAdmin ? (
          <Field label="Selling options">
            <SellingOptionsEditor
              value={sellingOptions}
              onChange={setSellingOptions}
              unitCost={Number(cost) || 0}
              unit={unit}
              showMargin
              error={sellingOptionsError}
            />
          </Field>
        ) : null}

        <Field label="Notes">
          <textarea rows={2} className={`${inputCls} resize-y leading-relaxed`}
            aria-label="Notes" value={notes} onChange={(e) => setNotes(e.target.value)} />
        </Field>

        <div className="flex justify-end gap-tk-sm pt-tk-sm">
          <button type="button" onClick={() => { reset(); onClose(); }}
            className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
            Cancel
          </button>
          <button type="button" onClick={submit}
            className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark">
            {initial ? 'Save changes' : 'Add to receiving'}
          </button>
        </div>
      </div>
    </Dialog>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-tk-xs block text-bodySmall text-light-text-secondary">{label}</span>
      {children}
    </label>
  );
}

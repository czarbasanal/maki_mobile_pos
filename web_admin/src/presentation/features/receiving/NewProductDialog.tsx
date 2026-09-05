// Full-field "new product" form for the receiving entry page, in a modal —
// replacing an 8-field inline grid that was too cramped to read. Mirrors the
// New Product page's fields except the image (a draft receiving persists plain
// data to Firestore, and a pending image file would silently vanish on
// save-as-draft; photos are added from the product drawer after receiving).
//
// Skin: the inventory ProductModal's — shared Modal shell, formKit controls,
// SelectFilter for Unit/Category, the same section grids and the live margin
// tile — so "new product" looks the same wherever it is asked for.
//
// Auto-SKU is the category-driven kind, matching the New Product page: picking
// a coded category peeks the next sequence for a PREVIEW, and the real claim
// happens inside the receive transaction (executeReceivePlan scans forward
// under the category code) — the retired name-based generator is not used.
// Nothing is created here: the dialog only queues a pendingNewProduct line;
// the product exists once the receiving is completed.
import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { CubeIcon } from '@heroicons/react/24/outline';
import { Modal } from '@/presentation/components/ui/Modal';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import { controlH, inputCls, Field, SectionLabel } from '@/presentation/components/ui/formKit';
import { SellingOptionsEditor } from '@/presentation/features/inventory/SellingOptionsEditor';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { useAuthStore } from '@/presentation/stores/authStore';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { UserRole } from '@/domain/enums';
import { composeAutoSku, matchesAutoPattern } from '@/domain/products/sku';
import { PENDING_SKU_LABEL } from '@/domain/receiving/skuPreview';
import { validateSellingOptions } from '@/domain/products/sellingOptions';
import { marginPct, marginToneClass } from '@/domain/products/margin';
import { cn } from '@/core/utils/cn';
import type { Category, SellingOption } from '@/domain/entities';
import type { NewProductSpec } from './useReceivingEntry';

interface NewProductDialogProps {
  open: boolean;
  onClose: () => void;
  /** Queues (or, in edit mode, replaces) the line; creation happens when the
   *  receiving completes. */
  onAdd: (spec: NewProductSpec) => void;
  /** Edit mode: prefill from an already-queued line's spec. */
  initial?: NewProductSpec | null;
  /** Create mode only: prefills Name from the add bar's no-results query, so
   *  confirming "not in the catalog" doesn't mean retyping what was just
   *  searched for. */
  initialName?: string;
}

export function NewProductDialog({
  open,
  onClose,
  onAdd,
  initial = null,
  initialName,
}: NewProductDialogProps) {
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

  // Create mode only: seed Name from the add bar's no-results query.
  useEffect(() => {
    if (!open || initial || !initialName) return;
    setName(initialName);
  }, [open, initial, initialName]);

  const sellingOptionsError = useMemo(
    () => validateSellingOptions(sellingOptions),
    [sellingOptions],
  );

  // Same live margin the inventory modal shows: the buyer should never have
  // to compute the one number that decides whether the price is right.
  const liveMargin = useMemo(() => {
    const c = Number(cost);
    const p = Number(price);
    if (!Number.isFinite(c) || !Number.isFinite(p) || price.trim() === '') return null;
    return marginPct(p, c);
  }, [cost, price]);

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

  const requestClose = () => { reset(); onClose(); };

  const submit = (e?: FormEvent) => {
    e?.preventDefault();
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

  const unitOptions = useMemo(() => {
    const names = (units ?? []).map((u) => u.name);
    return names.includes(unit) ? names : [...names, unit];
  }, [units, unit]);

  return (
    <Modal
      open={open}
      onClose={requestClose}
      title={initial ? 'Edit product' : 'New product'}
      subtitle="Added to inventory when this receiving is completed. Photo can be added afterward from the product page."
      icon={
        <div
          aria-hidden
          className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[10px] bg-accent-soft text-accent-text"
        >
          <CubeIcon className="h-[18px] w-[18px]" />
        </div>
      }
      widthClassName="max-w-[680px]"
      footer={
        <>
          <span className="ml-auto" />
          <button
            type="button"
            onClick={requestClose}
            className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-sm text-ink-2 hover:bg-surface-2"
          >
            Cancel
          </button>
          <button
            type="submit"
            form="receiving-new-product"
            className="rounded-ctl bg-accent px-tk-md py-tk-sm text-ctl-sm font-semibold text-accent-ink hover:brightness-95"
          >
            {initial ? 'Save changes' : 'Add to receiving'}
          </button>
        </>
      }
    >
      {error ? (
        <p className="rounded-ctl border border-neg bg-neg-soft px-tk-md py-tk-sm text-ctl-sm text-neg">
          {error}
        </p>
      ) : null}

      <form id="receiving-new-product" onSubmit={submit} noValidate className="flex flex-col gap-[18px]">
        <Field label="Name">
          <input
            data-autofocus
            type="text"
            className={inputCls(false)}
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </Field>

        <div className="grid grid-cols-[repeat(auto-fit,minmax(240px,1fr))] gap-3">
          <div className="flex flex-col gap-[6px]">
            {/* Auto sits right AFTER the SKU label — pushed to the column edge
                it lands nearer "Barcodes" and reads as a barcode control. */}
            <span className="flex items-center gap-[9px] text-[11.5px] font-semibold text-ink-2">
              SKU
              <label className="flex cursor-pointer items-center gap-1.5 font-medium text-ink-3">
                <input
                  type="checkbox"
                  className="h-3.5 w-3.5"
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
                Auto
              </label>
            </span>
            {/* readOnly, not disabled: while auto is on the field is genuinely
                locked, and its text stays legible on the --surface-3 fill.
                An auto row shows the pending label, never the seed — the seed
                is not the code the product ends up with. */}
            <input
              type="text"
              readOnly={autoSku}
              aria-label="SKU"
              className={cn(inputCls(false), 'font-mono', autoSku && 'cursor-default bg-surface-3')}
              value={autoSku && sku ? PENDING_SKU_LABEL : sku}
              onChange={(e) => setSku(e.target.value)}
            />
            {skuHint ? <span className="text-[11.5px] text-ink-3">{skuHint}</span> : null}
          </div>

          <Field group label="Barcodes">
            <div className="flex flex-col gap-2">
              {barcodes.length ? (
                <div className="flex flex-wrap gap-1.5">
                  {barcodes.map((code) => (
                    <span
                      key={code}
                      className="inline-flex items-center gap-1.5 rounded-pill bg-surface-2 px-2.5 py-[2px] text-[12px] text-ink"
                    >
                      <span className="font-mono">{code}</span>
                      <button
                        type="button"
                        onClick={() => setBarcodes((list) => list.filter((x) => x !== code))}
                        className="text-ink-3 hover:text-neg"
                        aria-label={`Remove barcode ${code}`}
                      >
                        ×
                      </button>
                    </span>
                  ))}
                </div>
              ) : null}
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  aria-label="Add barcode"
                  value={barcodeDraft}
                  onChange={(e) => setBarcodeDraft(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') { e.preventDefault(); commitBarcode(); }
                  }}
                  placeholder="Scan or type, then Enter"
                  className={cn(inputCls(false), 'font-mono')}
                />
                <button
                  type="button"
                  onClick={commitBarcode}
                  className="shrink-0 rounded-ctl border border-line px-tk-md py-2.5 text-ctl-sm text-ink hover:bg-surface-2"
                >
                  Add
                </button>
              </div>
            </div>
          </Field>
        </div>

        <section className="flex flex-col gap-2">
          <SectionLabel>Pricing</SectionLabel>
          <div className={threeColGrid}>
            <Field label="Cost">
              <input type="number" step="0.01" className={inputCls(false)}
                value={cost} onChange={(e) => setCost(e.target.value)} />
            </Field>
            <Field label="Price">
              <input type="number" step="0.01" className={inputCls(false)}
                value={price} onChange={(e) => setPrice(e.target.value)} />
            </Field>
            {/* Label and value on ONE line, same height as the inputs, so the
                tile reads as the row's third member — not a card. */}
            <div className={cn(controlH, 'flex items-center gap-2.5 rounded-ctl bg-surface-2 px-3')}>
              <span className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">Margin</span>
              <span className={cn('ml-auto font-mono text-[17px] font-semibold leading-none', marginToneClass(liveMargin))}>
                {liveMargin === null ? '—' : `${liveMargin}%`}
              </span>
            </div>
          </div>
        </section>

        {isAdmin ? (
          <section className="flex flex-col gap-2">
            <SectionLabel>Selling options</SectionLabel>
            <SellingOptionsEditor
              value={sellingOptions}
              onChange={setSellingOptions}
              unitCost={Number(cost) || 0}
              unit={unit}
              showMargin
              error={sellingOptionsError}
            />
          </section>
        ) : null}

        <section className="flex flex-col gap-2">
          <SectionLabel>Stock &amp; classification</SectionLabel>
          <div className={threeColGrid}>
            <Field label="Quantity received">
              <input type="number" className={inputCls(false)}
                value={quantity} onChange={(e) => setQuantity(e.target.value)} />
            </Field>
            <Field label="Reorder level">
              <input type="number" placeholder="1" className={inputCls(false)}
                value={reorderLevel} onChange={(e) => setReorderLevel(e.target.value)} />
            </Field>
          </div>
          <div className={threeColGrid}>
            <Field group label="Unit">
              <SelectFilter
                label="Unit"
                // No allLabel: a unit is required, so no "no filter" row
                // exists and '' is never offered.
                value={unit}
                options={unitOptions.map((u) => ({ value: u, label: u }))}
                onChange={setUnit}
                triggerClassName={formSelectCls}
              />
            </Field>
            <Field group label="Category">
              <SelectFilter
                label="Category"
                value={category ?? ''}
                options={(productCats ?? []).map((c) => ({ value: c.name, label: c.name }))}
                allLabel="(none)"
                onChange={(v) => {
                  const next = v || null;
                  setCategory(next);
                  applyCategoryForSku(next ? categoryEntityForName(next) : undefined, autoSku);
                }}
                triggerClassName={formSelectCls}
              />
            </Field>
          </div>
        </section>

        <Field label="Notes">
          <textarea
            rows={3}
            className={cn(inputCls(false), 'min-h-[74px] resize-y leading-normal')}
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
          />
        </Field>
      </form>
    </Modal>
  );
}

// The product modal's shared row rule: three columns on one set of vertical
// edges; 186px floors the tracks so SelectFilter's min width can't overflow.
const threeColGrid = 'grid grid-cols-[repeat(auto-fit,minmax(186px,1fr))] items-end gap-3';
const formSelectCls = `${controlH} w-full bg-surface-2 shadow-none`;

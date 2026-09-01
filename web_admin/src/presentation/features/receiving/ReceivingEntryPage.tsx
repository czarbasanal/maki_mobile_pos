import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { PencilSquareIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useReceivingEntry, type NewProductSpec } from './useReceivingEntry';
import { NewProductDialog } from './NewProductDialog';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import type { Product } from '@/domain/entities';
import { displaySku } from '@/domain/products/sku';
import { skuCellText } from '@/domain/receiving/skuPreview';


export function ReceivingEntryPage() {
  const entry = useReceivingEntry();

  const [picked, setPicked] = useState<Product | null>(null);
  const [qty, setQty] = useState('1');
  const [cost, setCost] = useState('');
  const [price, setPrice] = useState('');
  const [showNew, setShowNew] = useState(false);
  // Line being edited via the row pencil: the picked box (existing product)
  // or the product dialog (pending new product) reopens on it, and the
  // confirm rewrites the line instead of appending one.
  const [editingLineId, setEditingLineId] = useState<string | null>(null);
  const [editingSpec, setEditingSpec] = useState<NewProductSpec | null>(null);

  useEffect(() => {
    document.title = `${entry.isResuming ? 'Resume' : 'New'} receiving · MAKI POS Admin`;
  }, [entry.isResuming]);

  function pick(p: Product) {
    setPicked(p);
    setEditingLineId(null);
    setQty('1');
    setCost(String(p.cost));
    setPrice(String(p.price));
  }

  // The price only applies when the entered cost spawns a variation; a plain
  // top-up never touches the existing product's price.
  const costDiffers = picked != null && Math.abs(Number(cost) - picked.cost) > 0.01;

  function confirmExisting() {
    if (!picked) return;
    const q = Number(qty);
    const c = Number(cost);
    const pr = Number(price);
    if (!Number.isFinite(q) || q <= 0 || !Number.isFinite(c) || c < 0) return;
    if (costDiffers && (!Number.isFinite(pr) || pr < 0)) return;
    const unitPrice = costDiffers ? pr : null;
    if (editingLineId) {
      entry.updateExisting(editingLineId, { quantity: q, unitCost: c, unitPrice });
    } else {
      entry.addExisting(picked, q, c, unitPrice);
    }
    setPicked(null);
    setEditingLineId(null);
  }

  function editLine(l: (typeof entry.lines)[number]) {
    if (l.pendingNewProduct) {
      const np = l.pendingNewProduct;
      setEditingSpec({
        name: l.name,
        sku: l.sku,
        autoGenerateSku: np.autoGenerateSku,
        category: np.category,
        unit: l.unit,
        cost: l.unitCost,
        price: np.price,
        quantity: l.quantity,
        reorderLevel: np.reorderLevel,
        autoSkuCategoryCode: np.autoSkuCategoryCode ?? null,
        barcodes: np.barcodes ?? [],
        notes: np.notes ?? null,
        sellingOptions: np.sellingOptions ?? [],
      });
      setEditingLineId(l.id);
      // Close the inline box if another line was mid-edit — leaving it open
      // would silently degrade its Update back into an appending Add.
      setPicked(null);
      setShowNew(true);
      return;
    }
    const product = entry.products.find((p) => p.id === l.productId);
    if (!product) return;
    setPicked(product);
    setEditingLineId(l.id);
    setQty(String(l.quantity));
    setCost(String(l.unitCost));
    setPrice(String(l.unitPrice ?? product.price));
  }


  // The receiving line denormalizes cost but not the selling price, so a line
  // for an existing product resolves it from the product. A product deleted
  // since the receiving was written has none to show.
  const priceByProductId = new Map(entry.products.map((p) => [p.id, p.price]));
  const sellingPriceText = (l: (typeof entry.lines)[number]): string => {
    const price =
      l.unitPrice ?? l.pendingNewProduct?.price ?? priceByProductId.get(l.productId ?? '');
    return price == null ? '—' : formatMoney(price);
  };

  return (
    <div className="space-y-tk-lg">
      <header className="space-y-tk-xs">
        <Link
          to={RoutePaths.receiving}
          className="text-bodySmall text-light-text-secondary hover:underline"
        >
          ← Back to receiving
        </Link>
        <span className="block font-mono text-bodySmall text-light-text-secondary">
          {entry.referenceNumber ?? '…'}
        </span>
      </header>

      {entry.error ? (
        <div className="rounded-md border border-error bg-error-light px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {entry.error}
        </div>
      ) : null}

      {/* Supplier */}
      <div className="max-w-sm">
        <label className="mb-tk-xs block text-bodySmall font-medium text-light-text">Supplier</label>
        <select
          value={entry.supplierId}
          onChange={(e) => entry.setSupplierId(e.target.value)}
          className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-[8px] text-bodySmall text-light-text"
        >
          <option value="">No supplier</option>
          {entry.suppliers.map((s) => (
            <option key={s.id} value={s.id}>{s.name}</option>
          ))}
        </select>
      </div>

      {/* Add item */}
      <section className="space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-lg">
        <div className="flex items-center justify-between">
          <h2 className="text-bodyMedium font-semibold text-light-text">Add items</h2>
          <button
            type="button"
            onClick={() => { setShowNew(true); setPicked(null); setEditingSpec(null); setEditingLineId(null); }}
            className="rounded-md border border-light-border px-tk-md py-[6px] text-bodySmall text-light-text hover:bg-light-subtle"
          >
            + New product
          </button>
        </div>

          <div className="relative">
            <input
              value={entry.search}
              onChange={(e) => entry.setSearch(e.target.value)}
              placeholder="Search a product by name or SKU…"
              className={inputCls}
            />
            {entry.matches.length > 0 && !picked ? (
              <ul className="absolute z-10 mt-1 max-h-64 w-full overflow-auto rounded-md border border-light-hairline bg-light-card shadow-lg">
                {entry.matches.map((p) => (
                  <li key={p.id}>
                    <button type="button" onClick={() => pick(p)}
                      className="flex w-full items-center justify-between px-tk-md py-tk-sm text-left text-bodySmall hover:bg-light-subtle">
                      <span className="text-light-text">{p.name} <span className="text-light-text-hint">{displaySku(p.sku)}</span></span>
                      <span className="tabular-nums text-light-text-secondary">{formatMoney(p.cost)}</span>
                    </button>
                  </li>
                ))}
              </ul>
            ) : null}
          </div>

        {picked ? (
          <div className="flex flex-wrap items-end gap-tk-sm rounded-md border border-light-hairline bg-light-subtle p-tk-md">
            <div className="text-bodySmall text-light-text">
              <span className="font-medium">{picked.name}</span>{' '}
              <span className="text-light-text-hint">{displaySku(picked.sku)}</span>
            </div>
            <Field label="Qty"><input type="number" className={inputCls} value={qty}
              onChange={(e) => setQty(e.target.value)} /></Field>
            <Field label="Unit cost"><input type="number" className={inputCls} value={cost}
              onChange={(e) => setCost(e.target.value)} /></Field>
            <Field label="Price">
              <input type="number" aria-label="Price" className={inputCls} value={price}
                disabled={!costDiffers}
                title={costDiffers ? undefined : 'Price applies when a cost change spawns a variation'}
                onChange={(e) => setPrice(e.target.value)} />
            </Field>
            {costDiffers ? (
              <span className="text-[11px] text-warning-dark">
                Cost differs → a {picked.baseSku ?? picked.sku}-N variation will be created at this cost and price
              </span>
            ) : null}
            <button type="button" onClick={confirmExisting}
              className="rounded-md bg-primary-dark px-tk-md py-[8px] text-bodySmall font-medium text-white hover:opacity-90">
              {editingLineId ? 'Update' : 'Add'}
            </button>
            <button type="button" onClick={() => { setPicked(null); setEditingLineId(null); }}
              className="px-tk-sm py-[8px] text-bodySmall text-light-text-secondary hover:underline">
              Cancel
            </button>
          </div>
        ) : null}
      </section>

      {/* Items */}
      <NewProductDialog
        open={showNew}
        initial={editingSpec}
        onClose={() => { setShowNew(false); setEditingSpec(null); setEditingLineId(null); }}
        onAdd={(spec) => {
          if (editingLineId && editingSpec) entry.updateNew(editingLineId, spec);
          else entry.addNew(spec);
          setEditingSpec(null);
          setEditingLineId(null);
        }}
      />

      <section className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <th className="px-tk-md py-tk-sm text-left font-medium">SKU</th>
              <th className="px-tk-md py-tk-sm text-left font-medium">Item name</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Cost</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Price</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Line total</th>
              <th className="px-tk-md py-tk-sm" />
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {entry.lines.length === 0 ? (
              <tr><td colSpan={7} className="px-tk-md py-tk-lg text-center text-light-text-hint">No items yet.</td></tr>
            ) : (
              entry.lines.map((l) => (
                <tr key={l.id}>
                  <td className="px-tk-md py-tk-sm font-mono text-light-text-secondary">
                    {skuCellText(l.sku, l.pendingNewProduct?.autoSkuCategoryCode != null)}
                  </td>
                  {/* The "New" badge describes the product, so it stays with
                      the name rather than the code. */}
                  <td className="px-tk-md py-tk-sm">
                    <span className="font-medium text-light-text">{l.name}</span>
                    {l.pendingNewProduct ? (
                      <span className="ml-tk-sm rounded-full bg-info-light px-tk-sm py-[1px] text-[10px] font-semibold uppercase text-info-dark">New</span>
                    ) : null}
                  </td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{l.quantity}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(l.unitCost)}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{sellingPriceText(l)}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(l.unitCost * l.quantity)}</td>
                  <td className="px-tk-md py-tk-sm text-right">
                    <div className="flex items-center justify-end gap-tk-sm">
                      <button type="button" onClick={() => editLine(l)}
                        disabled={!l.pendingNewProduct && !priceByProductId.has(l.productId ?? '')}
                        title={
                          !l.pendingNewProduct && !priceByProductId.has(l.productId ?? '')
                            ? 'Product no longer exists'
                            : undefined
                        }
                        className="text-light-text-hint hover:text-light-text disabled:opacity-40 disabled:hover:text-light-text-hint"
                        aria-label="Edit">
                        <PencilSquareIcon className="h-4 w-4" />
                      </button>
                      <button type="button" onClick={() => entry.removeLine(l.id)}
                        className="text-light-text-hint hover:text-error" aria-label="Remove">
                        <TrashIcon className="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>

      {/* Footer */}
      <div className="flex items-center justify-between">
        <div className="text-bodySmall text-light-text-secondary">
          Total <span className="tabular-nums text-light-text">{entry.totals.quantity}</span> units ·{' '}
          <span className="tabular-nums font-semibold text-light-text">{formatMoney(entry.totals.cost)}</span>
        </div>
        <div className="flex gap-tk-sm">
          <button type="button" disabled={entry.isBusy} onClick={entry.saveDraft}
            className="rounded-md border border-light-border px-tk-lg py-[8px] text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-50">
            Save draft
          </button>
          <button type="button" disabled={entry.isBusy || entry.lines.length === 0} onClick={entry.receive}
            className="rounded-md bg-primary-dark px-tk-lg py-[8px] text-bodySmall font-medium text-white hover:opacity-90 disabled:opacity-50">
            {entry.isBusy ? 'Receiving…' : 'Receive'}
          </button>
        </div>
      </div>
    </div>
  );
}

const inputCls =
  'w-full rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-bodySmall text-light-text';

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1 block text-[11px] font-medium uppercase tracking-wider text-light-text-hint">{label}</span>
      {children}
    </label>
  );
}

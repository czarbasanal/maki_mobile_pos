import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useReceivingEntry, type NewProductSpec } from './useReceivingEntry';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { generateSku } from '@/domain/products/sku';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import type { Product } from '@/domain/entities';

const blankNew: NewProductSpec = {
  name: '', sku: '', autoGenerateSku: true, category: null, unit: 'pcs',
  cost: 0, price: 0, quantity: 1, reorderLevel: 0,
};

export function ReceivingEntryPage() {
  const entry = useReceivingEntry();
  const { data: productCats } = useActiveCategories(CategoryKind.product);
  const { data: units } = useActiveCategories(CategoryKind.unit);

  const [picked, setPicked] = useState<Product | null>(null);
  const [qty, setQty] = useState('1');
  const [cost, setCost] = useState('');
  const [showNew, setShowNew] = useState(false);
  const [np, setNp] = useState<NewProductSpec>(blankNew);

  useEffect(() => {
    document.title = `${entry.isResuming ? 'Resume' : 'New'} receiving · MAKI POS Admin`;
  }, [entry.isResuming]);

  function pick(p: Product) {
    setPicked(p);
    setQty('1');
    setCost(String(p.cost));
  }

  function confirmExisting() {
    if (!picked) return;
    const q = Number(qty);
    const c = Number(cost);
    if (!Number.isFinite(q) || q <= 0 || !Number.isFinite(c) || c < 0) return;
    entry.addExisting(picked, q, c);
    setPicked(null);
  }

  function confirmNew() {
    const name = np.name.trim();
    if (!name) return;
    const sku = np.autoGenerateSku ? generateSku(name) : np.sku.trim();
    if (!sku) return;
    entry.addNew({ ...np, name, sku, autoGenerateSku: false });
    setNp(blankNew);
    setShowNew(false);
  }

  return (
    <div className="space-y-tk-lg px-tk-xl py-tk-lg">
      <header className="space-y-tk-xs">
        <Link
          to={RoutePaths.receiving}
          className="text-bodySmall text-light-text-secondary hover:underline"
        >
          ← Back to receiving
        </Link>
        <div className="flex flex-wrap items-baseline gap-tk-sm">
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            {entry.isResuming ? 'Resume receiving' : 'New receiving'}
          </h1>
          <span className="font-mono text-bodySmall text-light-text-secondary">
            {entry.referenceNumber ?? '…'}
          </span>
        </div>
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
            onClick={() => { setShowNew((v) => !v); setPicked(null); }}
            className="rounded-md border border-light-border px-tk-md py-[6px] text-bodySmall text-light-text hover:bg-light-subtle"
          >
            + New product
          </button>
        </div>

        {showNew ? (
          <div className="grid grid-cols-2 gap-tk-sm rounded-md border border-light-hairline bg-light-subtle p-tk-md md:grid-cols-3">
            <Field label="Name">
              <input className={inputCls} value={np.name}
                onChange={(e) => setNp({ ...np, name: e.target.value })} />
            </Field>
            <Field label="SKU">
              <div className="flex items-center gap-tk-xs">
                <input className={inputCls} disabled={np.autoGenerateSku}
                  value={np.autoGenerateSku ? '(auto)' : np.sku}
                  onChange={(e) => setNp({ ...np, sku: e.target.value })} />
                <label className="flex shrink-0 items-center gap-1 text-[11px] text-light-text-secondary">
                  <input type="checkbox" checked={np.autoGenerateSku}
                    onChange={(e) => setNp({ ...np, autoGenerateSku: e.target.checked })} />
                  auto
                </label>
              </div>
            </Field>
            <Field label="Category">
              <select className={inputCls} value={np.category ?? ''}
                onChange={(e) => setNp({ ...np, category: e.target.value || null })}>
                <option value="">—</option>
                {(productCats ?? []).map((c) => <option key={c.id} value={c.name}>{c.name}</option>)}
              </select>
            </Field>
            <Field label="Unit">
              <select className={inputCls} value={np.unit}
                onChange={(e) => setNp({ ...np, unit: e.target.value })}>
                {(units ?? []).map((u) => <option key={u.id} value={u.name}>{u.name}</option>)}
                {(units ?? []).every((u) => u.name !== np.unit) ? <option value={np.unit}>{np.unit}</option> : null}
              </select>
            </Field>
            <Field label="Cost"><input type="number" className={inputCls} value={np.cost || ''}
              onChange={(e) => setNp({ ...np, cost: Number(e.target.value) })} /></Field>
            <Field label="Price"><input type="number" className={inputCls} value={np.price || ''}
              onChange={(e) => setNp({ ...np, price: Number(e.target.value) })} /></Field>
            <Field label="Quantity"><input type="number" className={inputCls} value={np.quantity || ''}
              onChange={(e) => setNp({ ...np, quantity: Number(e.target.value) })} /></Field>
            <Field label="Reorder level"><input type="number" className={inputCls} value={np.reorderLevel || ''}
              onChange={(e) => setNp({ ...np, reorderLevel: Number(e.target.value) })} /></Field>
            <div className="col-span-2 flex items-end md:col-span-3">
              <button type="button" onClick={confirmNew}
                className="rounded-md bg-primary-dark px-tk-md py-[8px] text-bodySmall font-medium text-white hover:opacity-90">
                Add new product
              </button>
            </div>
          </div>
        ) : (
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
                      <span className="text-light-text">{p.name} <span className="text-light-text-hint">{p.sku}</span></span>
                      <span className="tabular-nums text-light-text-secondary">{formatMoney(p.cost)}</span>
                    </button>
                  </li>
                ))}
              </ul>
            ) : null}
          </div>
        )}

        {picked ? (
          <div className="flex flex-wrap items-end gap-tk-sm rounded-md border border-light-hairline bg-light-subtle p-tk-md">
            <div className="text-bodySmall text-light-text">
              <span className="font-medium">{picked.name}</span>{' '}
              <span className="text-light-text-hint">{picked.sku}</span>
            </div>
            <Field label="Qty"><input type="number" className={inputCls} value={qty}
              onChange={(e) => setQty(e.target.value)} /></Field>
            <Field label="Unit cost"><input type="number" className={inputCls} value={cost}
              onChange={(e) => setCost(e.target.value)} /></Field>
            {Number(cost) !== picked.cost ? (
              <span className="text-[11px] text-warning-dark">
                Cost differs → a {picked.baseSku ?? picked.sku}-N variation will be created
              </span>
            ) : null}
            <button type="button" onClick={confirmExisting}
              className="rounded-md bg-primary-dark px-tk-md py-[8px] text-bodySmall font-medium text-white hover:opacity-90">
              Add
            </button>
            <button type="button" onClick={() => setPicked(null)}
              className="px-tk-sm py-[8px] text-bodySmall text-light-text-secondary hover:underline">
              Cancel
            </button>
          </div>
        ) : null}
      </section>

      {/* Items */}
      <section className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <th className="px-tk-md py-tk-sm text-left font-medium">Item</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Unit cost</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Line total</th>
              <th className="px-tk-md py-tk-sm" />
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {entry.lines.length === 0 ? (
              <tr><td colSpan={5} className="px-tk-md py-tk-lg text-center text-light-text-hint">No items yet.</td></tr>
            ) : (
              entry.lines.map((l) => (
                <tr key={l.id}>
                  <td className="px-tk-md py-tk-sm">
                    <span className="font-medium text-light-text">{l.name}</span>
                    <span className="ml-tk-sm text-light-text-hint">{l.sku}</span>
                    {l.pendingNewProduct ? (
                      <span className="ml-tk-sm rounded-full bg-info-light px-tk-sm py-[1px] text-[10px] font-semibold uppercase text-info-dark">New</span>
                    ) : null}
                  </td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{l.quantity}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(l.unitCost)}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(l.unitCost * l.quantity)}</td>
                  <td className="px-tk-md py-tk-sm text-right">
                    <button type="button" onClick={() => entry.removeLine(l.id)}
                      className="text-light-text-hint hover:text-error" aria-label="Remove">
                      <TrashIcon className="h-4 w-4" />
                    </button>
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
          Total <span className="tabular-nums text-light-text">{entry.totals.quantity}</span> items ·{' '}
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

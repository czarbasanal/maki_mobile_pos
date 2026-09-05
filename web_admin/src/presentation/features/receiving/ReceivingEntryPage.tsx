// New Receiving builder — per design/maki-pos-new-receiving's Implementation
// Guide §2/§3/§7 (reskinned tokens; the guide's localStorage/centavos/
// server-allocated-reference notes are superseded by this repo's rulings:
// Firestore + version-guard drafts, pesos, and the existing client-side
// nextReferenceNumber() reservation — see useReceivingEntry).
//
// Direct-add replaces the old "pick → inline box → confirm" flow: a search
// result's Add/+1 appends or bumps a line immediately, and every existing-
// product line is edited in place (qty stepper, cost, price cells) rather
// than through a reopened box. A pending-new-product line is the one
// exception — its spec isn't inline-editable, so it keeps a pencil that
// reopens NewProductDialog (see useReceivingEntry's updateNew).
import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { PencilSquareIcon, PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useReceivingEntry, type NewProductSpec } from './useReceivingEntry';
import { NewProductDialog } from './NewProductDialog';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import { marginPct, marginToneClass } from '@/domain/products/margin';
import { costsDiffer } from '@/domain/products/costVariation';
import { skuCellText } from '@/domain/receiving/skuPreview';
import { ProductImage } from '@/presentation/components/common/ProductImage';
import { BackButton } from '@/presentation/components/ui/BackButton';
import { Badge } from '@/presentation/components/ui/Badge';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { FirstRunState } from '@/presentation/components/ui/TableEmptyStates';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import { StickyActionBar } from '@/presentation/components/ui/StickyActionBar';
import { Field, inputCls } from '@/presentation/components/ui/formKit';
import { useEscapeLayer } from '@/presentation/components/ui/escapeLayers';
import { cn } from '@/core/utils/cn';
import type { Product, ReceivingItem } from '@/domain/entities';

export function ReceivingEntryPage() {
  const entry = useReceivingEntry();
  const navigate = useNavigate();
  const searchRef = useRef<HTMLInputElement>(null);

  const [showNew, setShowNew] = useState(false);
  const [newInitialName, setNewInitialName] = useState<string | undefined>(undefined);
  // A pending-new line's pencil reopens the dialog in edit mode; its confirm
  // rewrites the line (updateNew) instead of appending one.
  const [editingLineId, setEditingLineId] = useState<string | null>(null);
  const [editingSpec, setEditingSpec] = useState<NewProductSpec | null>(null);

  const [highlight, setHighlight] = useState(0);
  const [suppressDropdown, setSuppressDropdown] = useState(false);
  const dropdownOpen = entry.search.trim() !== '' && !suppressDropdown;
  useEscapeLayer(dropdownOpen, () => setSuppressDropdown(true));
  useEffect(() => setHighlight(0), [entry.matches]);

  useEffect(() => {
    document.title = `${entry.isResuming ? 'Resume' : 'New'} receiving · MAKI POS Admin`;
  }, [entry.isResuming]);

  const productsById = useMemo(
    () => new Map(entry.products.map((p) => [p.id, p])),
    [entry.products],
  );
  const lineProductIds = useMemo(
    () => new Set(entry.lines.filter((l) => !l.pendingNewProduct).map((l) => l.productId)),
    [entry.lines],
  );

  function pick(product: Product) {
    entry.addExisting(product);
    setSuppressDropdown(false);
    // Autofocus after every add (guide §2) — a scanned box's next barcode
    // must land in the search field without a click.
    searchRef.current?.focus();
  }

  function openNewProduct(initialName?: string) {
    setEditingSpec(null);
    setEditingLineId(null);
    setNewInitialName(initialName);
    setShowNew(true);
  }

  function editPendingLine(l: ReceivingItem) {
    const np = l.pendingNewProduct;
    if (!np) return;
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
    setNewInitialName(undefined);
    setShowNew(true);
  }

  /** Effective sell price a margin/price cell shows: the catalog price while
   *  the line's cost matches it, the line's own price once it diverges (the
   *  cost-variation policy) — and the queued spec's price for a pending-new
   *  line, which was never in the catalog to begin with. */
  function effectivePrice(l: ReceivingItem, product: Product | undefined): number | null {
    if (l.pendingNewProduct) return l.pendingNewProduct.price;
    if (!product) return null;
    return costsDiffer(l.unitCost, product.cost) ? (l.unitPrice ?? product.price) : product.price;
  }

  function handleSearchKeyDown(e: KeyboardEvent<HTMLInputElement>, currentText: string) {
    if (e.key === 'ArrowDown') {
      if (!dropdownOpen || entry.matches.length === 0) return;
      e.preventDefault();
      setHighlight((h) => Math.min(h + 1, entry.matches.length - 1));
      return;
    }
    if (e.key === 'ArrowUp') {
      if (!dropdownOpen || entry.matches.length === 0) return;
      e.preventDefault();
      setHighlight((h) => Math.max(h - 1, 0));
      return;
    }
    if (e.key === 'Enter') {
      // A wedge scanner's Enter follows its last character almost instantly
      // — well inside the 250ms debounce — so this resolves against the
      // LIVE input text (currentText, straight from the DOM), never
      // entry.matches (debounced). No dropdownOpen gate here: a scan can
      // fire before the dropdown has ever opened.
      const sole = entry.resolveSoleMatch(currentText);
      if (sole) {
        e.preventDefault();
        pick(sole);
        return;
      }
      // Otherwise: Enter selects whatever is highlighted in the (debounced,
      // already-rendered) dropdown — a deliberate arrow-key pick, not a scan.
      if (dropdownOpen && entry.matches.length > 0) {
        e.preventDefault();
        const chosen = entry.matches[highlight] ?? entry.matches[0];
        pick(chosen);
      }
    }
  }

  const columns: Array<Column<ReceivingItem>> = [
    {
      key: 'item',
      header: 'Item',
      render: (l) => {
        const product = l.pendingNewProduct ? undefined : productsById.get(l.productId ?? '');
        return (
          <div className="flex min-w-0 items-center gap-2.5">
            <ProductImage
              src={product?.imageUrl}
              alt={l.name}
              size="sm"
              className="h-[34px] w-[34px] shrink-0 rounded-[9px]"
            />
            <div className="flex min-w-0 flex-col gap-[2px]">
              <span className="flex items-center gap-1.5 text-ctl-sm font-medium text-ink">
                {l.name}
                {l.pendingNewProduct ? <Badge tone="info">New</Badge> : null}
              </span>
              {product ? (
                <span className="text-[10.5px] text-ink-3">
                  {product.quantity} on hand → {product.quantity + l.quantity}
                </span>
              ) : null}
            </div>
          </div>
        );
      },
    },
    {
      key: 'sku',
      header: 'SKU',
      width: '128px',
      mono: true,
      render: (l) => (
        <span className="whitespace-nowrap text-[12px] text-ink-2">
          {skuCellText(l.sku, l.pendingNewProduct?.autoSkuCategoryCode != null)}
        </span>
      ),
    },
    {
      key: 'qty',
      header: 'Qty',
      align: 'right',
      width: '112px',
      render: (l) =>
        l.pendingNewProduct ? (
          <span className="font-mono text-ctl-sm text-ink">{l.quantity}</span>
        ) : (
          <div className="flex items-center justify-end gap-[5px]">
            <button
              type="button"
              aria-label={`Decrease quantity for ${l.name}`}
              onClick={() => entry.updateLine(l.id, { quantity: l.quantity - 1 })}
              className="flex h-[30px] w-[26px] shrink-0 items-center justify-center rounded-ctl border border-line text-ink-2 hover:border-accent-line hover:text-ink"
            >
              −
            </button>
            <input
              type="number"
              aria-label={`Quantity for ${l.name}`}
              value={l.quantity}
              onChange={(e) => entry.updateLine(l.id, { quantity: Number(e.target.value) })}
              className="h-[30px] w-12 rounded-ctl border border-line bg-surface-2 text-center font-mono text-ctl-sm text-ink outline-none focus:border-accent-line"
            />
            <button
              type="button"
              aria-label={`Increase quantity for ${l.name}`}
              onClick={() => entry.updateLine(l.id, { quantity: l.quantity + 1 })}
              className="flex h-[30px] w-[26px] shrink-0 items-center justify-center rounded-ctl border border-line text-ink-2 hover:border-accent-line hover:text-ink"
            >
              +
            </button>
          </div>
        ),
    },
    {
      key: 'cost',
      header: 'Unit cost',
      align: 'right',
      width: '108px',
      render: (l) => {
        const product = l.pendingNewProduct ? undefined : productsById.get(l.productId ?? '');
        if (l.pendingNewProduct || !product) {
          return <span className="font-mono text-ctl-sm text-ink-2">{formatMoney(l.unitCost)}</span>;
        }
        const deviates = costsDiffer(l.unitCost, product.cost);
        return (
          <input
            type="number"
            aria-label={`Unit cost for ${l.name}`}
            value={l.unitCost}
            onChange={(e) => entry.updateLine(l.id, { unitCost: Number(e.target.value) })}
            className={cn(
              'h-[30px] w-full rounded-ctl border bg-surface-2 px-2 text-right font-mono text-ctl-sm text-ink outline-none',
              deviates ? 'border-accent-text' : 'border-line focus:border-accent-line',
            )}
          />
        );
      },
    },
    {
      key: 'price',
      header: 'Sell price',
      align: 'right',
      width: '108px',
      render: (l) => {
        const product = l.pendingNewProduct ? undefined : productsById.get(l.productId ?? '');
        if (l.pendingNewProduct) {
          return <span className="font-mono text-ctl-sm text-ink-2">{formatMoney(l.pendingNewProduct.price)}</span>;
        }
        if (!product) return <span className="text-ink-3">—</span>;
        const editable = costsDiffer(l.unitCost, product.cost);
        return (
          <input
            type="number"
            aria-label={`Price for ${l.name}`}
            title={editable ? undefined : 'Price applies when a cost change spawns a variation'}
            value={editable ? l.unitPrice ?? product.price : product.price}
            disabled={!editable}
            onChange={(e) => entry.updateLine(l.id, { unitPrice: Number(e.target.value) })}
            className={cn(
              'h-[30px] w-full rounded-ctl border bg-surface-2 px-2 text-right font-mono text-ctl-sm text-ink outline-none disabled:text-ink-3',
              editable && l.unitPrice != null ? 'border-accent-text' : 'border-line focus:border-accent-line',
            )}
          />
        );
      },
    },
    {
      key: 'margin',
      header: 'Margin',
      align: 'right',
      width: '78px',
      render: (l) => {
        const product = l.pendingNewProduct ? undefined : productsById.get(l.productId ?? '');
        const price = effectivePrice(l, product);
        const pct = price != null ? marginPct(price, l.unitCost) : null;
        return (
          <span className={cn('font-mono text-[12px] font-semibold', marginToneClass(pct))}>
            {pct == null ? '—' : `${pct}%`}
          </span>
        );
      },
    },
    {
      key: 'total',
      header: 'Line total',
      align: 'right',
      width: '110px',
      mono: true,
      render: (l) => (
        <span className="text-[13px] font-semibold text-ink">{formatMoney(l.unitCost * l.quantity)}</span>
      ),
    },
    {
      key: 'actions',
      header: '',
      align: 'right',
      width: '64px',
      render: (l) => (
        <div className="flex items-center justify-end gap-1">
          {l.pendingNewProduct ? (
            <button
              type="button"
              aria-label="Edit"
              onClick={() => editPendingLine(l)}
              className="flex h-[26px] w-[26px] items-center justify-center rounded-[7px] text-ink-3 hover:bg-surface-3 hover:text-ink-2"
            >
              <PencilSquareIcon className="h-3.5 w-3.5" />
            </button>
          ) : null}
          <button
            type="button"
            aria-label="Remove"
            title="Remove line"
            onClick={() => entry.removeLine(l.id)}
            className="flex h-[26px] w-[26px] items-center justify-center rounded-[7px] text-ink-3 hover:bg-neg-soft hover:text-neg"
          >
            <TrashIcon className="h-3.5 w-3.5" />
          </button>
        </div>
      ),
    },
  ];

  const retailValue = entry.lines.reduce((sum, l) => {
    const product = l.pendingNewProduct ? undefined : productsById.get(l.productId ?? '');
    const price = effectivePrice(l, product);
    return price == null ? sum : sum + price * l.quantity;
  }, 0);

  const receiveDisabled = entry.isBusy || entry.lines.length === 0;

  return (
    <div className="flex flex-col gap-3">
      <BackButton onClick={() => navigate(RoutePaths.receiving)} />

      {entry.error ? (
        <p className="rounded-ctl border border-neg bg-neg-soft px-3.5 py-2.5 text-ctl-sm text-neg">
          {entry.error}
        </p>
      ) : null}

      <section className="overflow-visible rounded-card border border-line bg-surface shadow-card">
        {/* Header */}
        <div className="flex flex-wrap items-center gap-2.5 border-b border-line-2 px-5 py-4">
          <span className="flex items-center gap-2 font-mono text-[19px] font-semibold tracking-[-0.6px] text-ink">
            {entry.referenceNumber ?? '…'}
            {entry.referenceNumber ? <CopyButton value={entry.referenceNumber} label="reference" /> : null}
          </span>
          <Badge tone="info">Draft</Badge>
          <span className="text-[11.5px] text-ink-3">Nothing moves until you receive it</span>
        </div>

        {/* Meta grid */}
        <div className="grid grid-cols-[repeat(auto-fit,minmax(220px,1fr))] gap-3 border-b border-line-2 px-5 py-4">
          <Field label="Supplier" group>
            <SelectFilter
              label="Supplier"
              value={entry.supplierId}
              options={entry.suppliers.map((s) => ({ value: s.id, label: s.name }))}
              onChange={entry.setSupplierId}
              allLabel="No supplier"
              triggerClassName="h-[42px] w-full bg-surface-2 shadow-none"
            />
          </Field>
          <Field label="Invoice / DR no.">
            <input
              value={entry.invoiceNumber}
              onChange={(e) => entry.setInvoiceNumber(e.target.value)}
              placeholder="From the supplier's paperwork"
              className={cn(inputCls(), 'font-mono')}
            />
          </Field>
          <Field label="Received">
            <input
              type="date"
              value={entry.receivedOn}
              onChange={(e) => entry.setReceivedOn(e.target.value)}
              className={cn(inputCls(), 'font-mono')}
            />
          </Field>
        </div>

        {/* Add bar */}
        <div className="flex flex-wrap items-center gap-2.5 border-b border-line-2 px-5 py-3.5">
          <div className="relative min-w-[240px] flex-1">
            <SearchInput
              value={entry.search}
              onChange={(v) => {
                entry.setSearch(v);
                setSuppressDropdown(false);
              }}
              onKeyDown={(e, currentText) => handleSearchKeyDown(e, currentText)}
              placeholder="Search a part by name or SKU — or scan a barcode"
              variant="hero"
              debounce={0}
              autoFocus
              inputRef={searchRef}
            />
            {dropdownOpen ? (
              <div
                data-testid="search-results"
                className="absolute left-0 right-0 top-[calc(100%+6px)] z-40 max-h-64 overflow-y-auto rounded-card border border-line bg-surface p-[5px] shadow-card"
              >
                {entry.matches.map((p, i) => (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => pick(p)}
                    className={cn(
                      'flex w-full items-center gap-2.5 rounded-field px-2.5 py-2 text-left',
                      i === highlight ? 'bg-surface-2' : 'hover:bg-surface-2',
                    )}
                  >
                    <ProductImage src={p.imageUrl} alt={p.name} size="sm" className="h-[30px] w-[30px] shrink-0 rounded-[8px]" />
                    <span className="flex min-w-0 flex-col gap-[2px]">
                      <span className="truncate text-[12.5px] font-medium text-ink">{p.name}</span>
                      <span className="whitespace-nowrap font-mono text-[10.5px] text-ink-3">
                        {p.sku} · {p.quantity} on hand · last cost {formatMoney(p.cost)}
                      </span>
                    </span>
                    <span className="ml-auto shrink-0 text-[11.5px] font-semibold text-accent-text">
                      {lineProductIds.has(p.id) ? '+1' : 'Add'}
                    </span>
                  </button>
                ))}
                {entry.moreMatches > 0 ? (
                  <div className="px-2.5 py-2 text-[11.5px] text-ink-3">
                    {entry.moreMatches} more — keep typing to narrow
                  </div>
                ) : null}
                {entry.matches.length === 0 ? (
                  <div className="flex flex-col gap-2 px-3 py-3.5">
                    <span className="text-[12.5px] text-ink-2">No part matches “{entry.search.trim()}”</span>
                    <button
                      type="button"
                      onClick={() => openNewProduct(entry.search.trim())}
                      className="w-fit rounded-ctl border border-line px-3 py-1.5 text-[12px] font-medium text-ink-2 hover:border-accent-line hover:text-ink"
                    >
                      + Create it as a new product
                    </button>
                  </div>
                ) : null}
              </div>
            ) : null}
          </div>
          <Button onClick={() => openNewProduct(undefined)} icon={<PlusIcon className="h-3.5 w-3.5" />}>
            New product
          </Button>
        </div>

        <NewProductDialog
          open={showNew}
          initial={editingSpec}
          initialName={newInitialName}
          onClose={() => {
            setShowNew(false);
            setEditingSpec(null);
            setEditingLineId(null);
            setNewInitialName(undefined);
          }}
          onAdd={(spec) => {
            if (editingLineId) entry.updateNew(editingLineId, spec);
            else entry.addNew(spec);
            setEditingSpec(null);
            setEditingLineId(null);
            setNewInitialName(undefined);
            searchRef.current?.focus();
          }}
        />

        {/* Line table */}
        <DataTable
          columns={columns}
          rows={entry.lines}
          rowKey={(l) => l.id}
          minWidth="900px"
          empty={
            <FirstRunState
              icon={
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--accent-text)" strokeWidth="1.6">
                  <path d="M12 3.2 20 7.4v9.2L12 20.8 4 16.6V7.4Z" />
                  <path d="M4 7.4 12 11.6l8-4.2" />
                  <line x1="12" y1="11.6" x2="12" y2="20.8" />
                </svg>
              }
              title="No items yet"
              description="Search a part above, or scan the barcode on the box. Costs default to what you last paid."
            />
          }
        />

        {/* Sticky footer */}
        <StickyActionBar
          figures={[
            { label: 'Lines', value: String(entry.lines.length) },
            { label: 'Units in', value: String(entry.totals.quantity) },
            { label: 'Retail value', value: formatMoney(retailValue), tone: 'pos' },
          ]}
        >
          <span className="flex items-baseline gap-2">
            <span className="text-[11.5px] text-ink-3">Total cost</span>
            <span className="tnum font-mono text-[23px] font-semibold tracking-[-1px] text-ink">
              {formatMoney(entry.totals.cost)}
            </span>
          </span>
          <Button disabled={entry.isBusy} onClick={entry.saveDraft}>
            Save draft
          </Button>
          {/* aria-disabled (not disabled): the .45-opacity treatment stays
             clickable-looking per the guide, and this is the actual gate —
             a real `disabled` attribute would also block Enter-to-submit
             detection consistently with the rest of the app's forms. */}
          <button
            type="button"
            aria-disabled={receiveDisabled || undefined}
            onClick={() => {
              if (!receiveDisabled) entry.receive();
            }}
            className={cn(
              'inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-ctl bg-accent px-3.5 py-[9px] text-ctl-md font-semibold text-accent-ink hover:brightness-95',
              receiveDisabled && 'cursor-default opacity-45',
            )}
          >
            {entry.isBusy ? 'Receiving…' : 'Receive into stock'}
          </button>
        </StickyActionBar>
      </section>
    </div>
  );
}

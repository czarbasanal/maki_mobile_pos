import { useEffect, useMemo, useRef, useState } from 'react';
import { useDebouncedValue } from '@/presentation/hooks/useDebouncedValue';
import { useNavigate, useParams } from 'react-router-dom';
import { useProducts } from '@/presentation/hooks/useProducts';
import { useSuppliers } from '@/presentation/hooks/useSuppliers';
import { useReceiving } from '@/presentation/hooks/useReceiving';
import {
  useCompleteReceiving,
  useCreateReceiving,
  useUpdateReceiving,
} from '@/presentation/hooks/useReceivingMutations';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useReceivingRepo } from '@/infrastructure/di/container';
import { filterProducts } from '@/domain/products/filterProducts';
import { costsDiffer } from '@/domain/products/costVariation';
import { shopIsoDate } from '@/domain/time/shopTime';
import { RoutePaths } from '@/presentation/router/routePaths';
import type { Product, ReceivingItem, SellingOption } from '@/domain/entities';
import type { ReceivingInput } from '@/domain/repositories/ReceivingRepository';

/** Dropdown cap (guide §2 add bar): mounting every match per keystroke jams
 *  fast entry, and a wedge scanner needs the box to stay short. */
const MAX_VISIBLE_MATCHES = 6;

/** A new-product line carries `pendingNewProduct`; an existing-product line has a
 *  real `productId`. Both are persisted as ReceivingItems on the draft. */
export interface NewProductSpec {
  name: string;
  sku: string;
  autoGenerateSku: boolean;
  category: string | null;
  unit: string;
  cost: number;
  price: number;
  quantity: number;
  reorderLevel: number;
  /** Category code when auto-SKU is on — the sku is then a peeked preview and
   *  the receive transaction claims the real sequence under this code. */
  autoSkuCategoryCode: string | null;
  barcodes: string[];
  notes: string | null;
  sellingOptions: SellingOption[];
}

export function useReceivingEntry() {
  const { id } = useParams();
  const navigate = useNavigate();
  const actor = useAuthStore((s) => s.user);
  const repo = useReceivingRepo();
  const { data: products, isLoading: productsLoading } = useProducts();
  const { data: suppliers } = useSuppliers();
  const existing = useReceiving(id ?? '');
  const create = useCreateReceiving();
  const update = useUpdateReceiving();
  const complete = useCompleteReceiving();

  const [supplierId, setSupplierId] = useState('');
  const [invoiceNumber, setInvoiceNumber] = useState('');
  // Seeded to the shop's calendar today — a delivery counted the next
  // morning must be dateable to the day it actually arrived, not the device's.
  const [receivedOn, setReceivedOn] = useState(() => shopIsoDate(new Date()));
  const [lines, setLines] = useState<ReceivingItem[]>([]);
  const [search, setSearch] = useState('');
  const [savedId, setSavedId] = useState<string | null>(id ?? null);
  const [referenceNumber, setReferenceNumber] = useState<string | null>(null);
  // The version this page last agreed with the server on. A save that does not
  // match the server's is refused rather than overwriting another device.
  const [version, setVersion] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const hydrated = useRef(false);

  const productsById = useMemo(
    () => new Map((products ?? []).map((p) => [p.id, p])),
    [products],
  );

  // New entry: reserve the next RCV-… reference up front, to show while drafting
  // and to reuse on save (create() honors a provided referenceNumber).
  useEffect(() => {
    if (id || referenceNumber !== null) return;
    let active = true;
    repo
      .nextReferenceNumber()
      .then((ref) => { if (active) setReferenceNumber(ref); })
      .catch(() => {});
    return () => { active = false; };
  }, [id, referenceNumber, repo]);

  // Hydrate once from a resumed draft.
  useEffect(() => {
    if (hydrated.current || !id || !existing.data) return;
    hydrated.current = true;
    setSupplierId(existing.data.supplierId ?? '');
    setLines(existing.data.items);
    setSavedId(existing.data.id);
    setReferenceNumber(existing.data.referenceNumber);
    setVersion(existing.data.version);
    setInvoiceNumber(existing.data.invoiceNumber ?? '');
    // Older drafts predate the field — fall back to today rather than
    // resuming with a blank date input.
    setReceivedOn(existing.data.receivedOn ?? shopIsoDate(new Date()));
  }, [id, existing.data]);

  // Debounced 250ms (guide §2): the suggestion box filters the whole
  // catalog per keystroke, and a wedge scanner's keystrokes arrive fast.
  const debouncedSearch = useDebouncedValue(search, 250);
  const allMatches = useMemo(
    () =>
      debouncedSearch.trim() && products
        ? filterProducts(products, {
            search: debouncedSearch,
            stock: 'all',
            category: 'all',
            status: 'active',
          })
        : [],
    [debouncedSearch, products],
  );
  const matches = useMemo(() => allMatches.slice(0, MAX_VISIBLE_MATCHES), [allMatches]);
  const moreMatches = allMatches.length - matches.length;

  const totals = useMemo(
    () => ({
      quantity: lines.reduce((n, l) => n + l.quantity, 0),
      cost: lines.reduce((n, l) => n + l.unitCost * l.quantity, 0),
    }),
    [lines],
  );

  /** Direct-add (guide §2): a search-result "Add"/"+1" click, or a wedge
   *  scanner's Enter. A product already on the receipt gets +1 to its
   *  quantity instead of a duplicate line — "non-variation-pending" because
   *  a pending-new line intentionally has no productId to match against. */
  function addExisting(product: Product) {
    setLines((ls) => {
      const idx = ls.findIndex((l) => l.productId === product.id && !l.pendingNewProduct);
      if (idx !== -1) {
        const next = [...ls];
        next[idx] = { ...next[idx], quantity: next[idx].quantity + 1 };
        return next;
      }
      return [
        ...ls,
        {
          id: crypto.randomUUID(),
          productId: product.id,
          sku: product.sku,
          name: product.name,
          quantity: 1,
          unit: product.unit,
          unitCost: product.cost,
          // Cost-variation policy is law: null until an inline cost edit
          // actually differs from the catalog (updateLine below) — the same
          // rule the old confirmExisting box enforced, now inline.
          unitPrice: null,
          costCode: product.costCode,
          isNewVariation: false,
          newProductId: null,
          notes: null,
          pendingNewProduct: null,
        },
      ];
    });
    setSearch('');
  }

  /** Inline edit for an existing-product line's qty/cost/price cells.
   *  Quantity floors at 1 (removing a line is the remove button's job, not
   *  a zero quantity). A cost edit that lands back within tolerance of the
   *  catalog cost drops any typed price — the price cell goes back to
   *  disabled the same instant, so a stale value must not linger on the
   *  line (exactly today's confirmExisting semantics, now inline). */
  function updateLine(
    lineId: string,
    patch: Partial<Pick<ReceivingItem, 'quantity' | 'unitCost' | 'unitPrice'>>,
  ) {
    setLines((ls) =>
      ls.map((l) => {
        if (l.id !== lineId) return l;
        const next: ReceivingItem = { ...l, ...patch };
        if (patch.quantity !== undefined) {
          next.quantity = Math.max(1, Math.floor(patch.quantity) || 1);
        }
        if (patch.unitCost !== undefined && !l.pendingNewProduct) {
          const product = productsById.get(l.productId ?? '');
          if (product == null || !costsDiffer(next.unitCost, product.cost)) {
            next.unitPrice = null;
          }
        }
        return next;
      }),
    );
  }

  /** Rebuilds a new-product line from an edited spec, keeping the line id. */
  function updateNew(lineId: string, spec: NewProductSpec) {
    setLines((ls) => ls.map((l) => (l.id === lineId ? { ...newLine(spec), id: lineId } : l)));
  }

  function addNew(spec: NewProductSpec) {
    setLines((ls) => [...ls, newLine(spec)]);
    setSearch('');
  }

  function newLine(spec: NewProductSpec): ReceivingItem {
    return {
      id: crypto.randomUUID(),
      productId: '',
      sku: spec.sku,
      name: spec.name,
      quantity: spec.quantity,
      unit: spec.unit,
      unitCost: spec.cost,
      unitPrice: null,
      costCode: '', // computed from cost at complete time
      isNewVariation: false,
      newProductId: null,
      notes: null,
      pendingNewProduct: {
        category: spec.category,
        price: spec.price,
        reorderLevel: spec.reorderLevel,
        autoGenerateSku: spec.autoGenerateSku,
        autoSkuCategoryCode: spec.autoSkuCategoryCode,
        barcodes: spec.barcodes,
        notes: spec.notes,
        sellingOptions: spec.sellingOptions,
      },
    };
  }

  function removeLine(lineId: string) {
    setLines((ls) => ls.filter((l) => l.id !== lineId));
  }

  function buildInput(): ReceivingInput {
    const supplier = suppliers?.find((s) => s.id === supplierId) ?? null;
    return {
      referenceNumber: referenceNumber ?? '',
      supplierId: supplier?.id ?? null,
      supplierName: supplier?.name ?? null,
      items: lines,
      totalCost: totals.cost,
      totalQuantity: totals.quantity,
      status: 'draft',
      notes: null,
      createdBy: actor?.id ?? '',
      createdByName: actor?.displayName ?? '',
      invoiceNumber: invoiceNumber.trim() || null,
      receivedOn,
    };
  }

  /** Persists the current lines as a draft, returning its id (creates on first save). */
  async function persistDraft(): Promise<string> {
    if (savedId) {
      await update.mutateAsync({
        id: savedId,
        input: buildInput(),
        expectedVersion: version,
      });
      // Our own write moved the doc forward; stay in step so a second save in
      // the same session is not mistaken for a conflict.
      setVersion((v) => v + 1);
      return savedId;
    }
    const created = await create.mutateAsync(buildInput());
    setSavedId(created.id);
    setVersion(created.version);
    return created.id;
  }

  async function saveDraft() {
    setError(null);
    try {
      await persistDraft();
      navigate(RoutePaths.receiving);
    } catch (e) {
      setError((e as Error).message);
    }
  }

  async function receive() {
    setError(null);
    if (lines.length === 0) {
      setError('Add at least one item before receiving.');
      return;
    }
    try {
      const targetId = await persistDraft();
      const supplier = suppliers?.find((s) => s.id === supplierId) ?? null;
      await complete.mutateAsync({
        id: targetId,
        referenceNumber: referenceNumber ?? '',
        itemCount: lines.length,
        totalCost: totals.cost,
        supplierName: supplier?.name ?? null,
      });
      // replace: the draft form is finished and refuses to reopen once
      // completed, so leaving it in history makes Back a dead end.
      navigate(`/receiving/${targetId}`, { replace: true });
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return {
    /** For resolving a line's selling price — the receiving line denormalizes
     *  cost but not price, so the table looks it up. */
    products: products ?? [],
    isResuming: !!id,
    referenceNumber,
    isLoadingRefs: productsLoading || (!!id && existing.isLoading),
    suppliers: suppliers ?? [],
    supplierId,
    setSupplierId,
    invoiceNumber,
    setInvoiceNumber,
    receivedOn,
    setReceivedOn,
    search,
    setSearch,
    matches,
    moreMatches,
    lines,
    addExisting,
    addNew,
    updateLine,
    updateNew,
    removeLine,
    totals,
    error,
    isBusy: create.isPending || update.isPending || complete.isPending,
    saveDraft,
    receive,
  };
}

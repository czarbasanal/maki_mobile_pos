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
import { RoutePaths } from '@/presentation/router/routePaths';
import type { Product, ReceivingItem, SellingOption } from '@/domain/entities';
import type { ReceivingInput } from '@/domain/repositories/ReceivingRepository';

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
  const [lines, setLines] = useState<ReceivingItem[]>([]);
  const [search, setSearch] = useState('');
  const [savedId, setSavedId] = useState<string | null>(id ?? null);
  const [referenceNumber, setReferenceNumber] = useState<string | null>(null);
  // The version this page last agreed with the server on. A save that does not
  // match the server's is refused rather than overwriting another device.
  const [version, setVersion] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const hydrated = useRef(false);

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
  }, [id, existing.data]);

  // Debounced + capped with a visible remainder: the suggestion box shows
  // ~4 rows, and mounting every match per keystroke jams fast entry.
  const debouncedSearch = useDebouncedValue(search);
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
  const matches = useMemo(() => allMatches.slice(0, 50), [allMatches]);
  const moreMatches = allMatches.length - matches.length;

  const totals = useMemo(
    () => ({
      quantity: lines.reduce((n, l) => n + l.quantity, 0),
      cost: lines.reduce((n, l) => n + l.unitCost * l.quantity, 0),
    }),
    [lines],
  );

  function addExisting(p: Product, quantity: number, unitCost: number, unitPrice: number | null = null) {
    setLines((ls) => [
      ...ls,
      {
        id: crypto.randomUUID(),
        productId: p.id,
        sku: p.sku,
        name: p.name,
        quantity,
        unit: p.unit,
        unitCost,
        // Meaningful only when the cost differs (a variation is spawned);
        // null inherits the base product's price.
        unitPrice,
        costCode: p.costCode,
        isNewVariation: false,
        newProductId: null,
        notes: null,
        pendingNewProduct: null,
      },
    ]);
    setSearch('');
  }

  /** Rewrites an existing-product line's editable fields in place. */
  function updateExisting(
    lineId: string,
    patch: { quantity: number; unitCost: number; unitPrice: number | null },
  ) {
    setLines((ls) => ls.map((l) => (l.id === lineId ? { ...l, ...patch } : l)));
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
    search,
    setSearch,
    matches,
    moreMatches,
    lines,
    addExisting,
    addNew,
    updateExisting,
    updateNew,
    removeLine,
    totals,
    error,
    isBusy: create.isPending || update.isPending || complete.isPending,
    saveDraft,
    receive,
  };
}

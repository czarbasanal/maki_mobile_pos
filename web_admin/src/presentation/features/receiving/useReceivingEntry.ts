import { useEffect, useMemo, useRef, useState } from 'react';
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
import { filterProducts } from '@/domain/products/filterProducts';
import { RoutePaths } from '@/presentation/router/routePaths';
import type { Product, ReceivingItem } from '@/domain/entities';
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
}

export function useReceivingEntry() {
  const { id } = useParams();
  const navigate = useNavigate();
  const actor = useAuthStore((s) => s.user);
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
  const [error, setError] = useState<string | null>(null);
  const hydrated = useRef(false);

  // Hydrate once from a resumed draft.
  useEffect(() => {
    if (hydrated.current || !id || !existing.data) return;
    hydrated.current = true;
    setSupplierId(existing.data.supplierId ?? '');
    setLines(existing.data.items);
    setSavedId(existing.data.id);
  }, [id, existing.data]);

  const matches = useMemo(
    () =>
      search.trim() && products
        ? filterProducts(products, { search, stock: 'all', category: 'all' }).slice(0, 8)
        : [],
    [search, products],
  );

  const totals = useMemo(
    () => ({
      quantity: lines.reduce((n, l) => n + l.quantity, 0),
      cost: lines.reduce((n, l) => n + l.unitCost * l.quantity, 0),
    }),
    [lines],
  );

  function addExisting(p: Product, quantity: number, unitCost: number) {
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
        costCode: p.costCode,
        isNewVariation: false,
        newProductId: null,
        notes: null,
        pendingNewProduct: null,
      },
    ]);
    setSearch('');
  }

  function addNew(spec: NewProductSpec) {
    setLines((ls) => [
      ...ls,
      {
        id: crypto.randomUUID(),
        productId: '',
        sku: spec.sku,
        name: spec.name,
        quantity: spec.quantity,
        unit: spec.unit,
        unitCost: spec.cost,
        costCode: '', // computed from cost at complete time
        isNewVariation: false,
        newProductId: null,
        notes: null,
        pendingNewProduct: {
          category: spec.category,
          price: spec.price,
          reorderLevel: spec.reorderLevel,
          autoGenerateSku: spec.autoGenerateSku,
        },
      },
    ]);
    setSearch('');
  }

  function removeLine(lineId: string) {
    setLines((ls) => ls.filter((l) => l.id !== lineId));
  }

  function buildInput(): ReceivingInput {
    const supplier = suppliers?.find((s) => s.id === supplierId) ?? null;
    return {
      referenceNumber: existing.data?.referenceNumber ?? '',
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
      await update.mutateAsync({ id: savedId, input: buildInput() });
      return savedId;
    }
    const created = await create.mutateAsync(buildInput());
    setSavedId(created.id);
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
      await complete.mutateAsync(targetId);
      navigate(`/receiving/${targetId}`);
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return {
    isResuming: !!id,
    isLoadingRefs: productsLoading || (!!id && existing.isLoading),
    suppliers: suppliers ?? [],
    supplierId,
    setSupplierId,
    search,
    setSearch,
    matches,
    lines,
    addExisting,
    addNew,
    removeLine,
    totals,
    error,
    isBusy: create.isPending || update.isPending || complete.isPending,
    saveDraft,
    receive,
  };
}

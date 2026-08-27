import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { CategoryKind } from '@/domain/categories/categoryKind';
import {
  useProductRepo,
  useSupplierRepo,
  useReceivingRepo,
} from '@/infrastructure/di/container';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { parseCsv } from '@/core/utils/csv';
import { parseReceivingRows } from '@/domain/receiving/parseReceivingRows';
import {
  classifyReceivingRows,
  resolveDuplicateName,
  type ClassifiedReceivingRow,
  type DuplicateNameResolution,
} from '@/domain/receiving/classifyReceivingRows';
import type { ReceivingResult } from '@/domain/repositories/ReceivingRepository';

interface ReceivingState {
  rows: ClassifiedReceivingRow[];
  headerError: string | null;
}

export function useBulkReceiving() {
  const productRepo = useProductRepo();
  const supplierRepo = useSupplierRepo();
  const receivingRepo = useReceivingRepo();
  const { data: costCode } = useCostCode();
  const user = useAuthStore((s) => s.user);

  const productsQuery = useQuery({ queryKey: ['products', 'all'], queryFn: () => productRepo.list() });
  const suppliersQuery = useQuery({ queryKey: ['suppliers', 'all'], queryFn: () => supplierRepo.list() });
  // Category name → auto-SKU code, for GENERATE rows. Rows whose category has
  // no code are rejected at classification.
  const { data: productCats } = useActiveCategories(CategoryKind.product);
  const categoryCodes = useMemo(
    () =>
      new Map(
        (productCats ?? [])
          .filter((c) => c.code !== undefined)
          .map((c) => [c.name, c.code as string]),
      ),
    [productCats],
  );

  const [state, setState] = useState<ReceivingState | null>(null);
  const [supplierId, setSupplierId] = useState<string>('');
  const [parseError, setParseError] = useState<string | null>(null);
  const [result, setResult] = useState<ReceivingResult | null>(null);
  const [isReceiving, setIsReceiving] = useState(false);
  // Row number -> the operator's choice for a `duplicate-name` row. Unset
  // rows default to "variation" (see resolvedRows below).
  const [duplicateResolutions, setDuplicateResolutions] = useState<Map<number, DuplicateNameResolution>>(new Map());

  function setDuplicateResolution(rowNumber: number, resolution: DuplicateNameResolution) {
    setDuplicateResolutions((m) => new Map(m).set(rowNumber, resolution));
  }

  // The rows actually used for the summary + receive: a `duplicate-name` row
  // is folded into `match`/`mismatch` (the default "variation" choice) or
  // `new`, so it flows through the existing cost-mismatch/variation
  // machinery unchanged. `state.rows` itself stays untouched so the preview
  // table can keep showing the duplicate-name badge and its resolver.
  const resolvedRows = useMemo(
    () =>
      (state?.rows ?? []).map((r) =>
        r.status === 'duplicate-name'
          ? resolveDuplicateName(r, duplicateResolutions.get(r.row.rowNumber) ?? 'variation')
          : r,
      ),
    [state, duplicateResolutions],
  );

  const ready = !!costCode && !!productsQuery.data && !!suppliersQuery.data && productCats !== undefined;

  async function parseFile(file: File) {
    setParseError(null);
    setResult(null);
    if (!ready) {
      setParseError('Still loading reference data — try again in a moment.');
      return;
    }
    let text: string;
    try {
      text = await file.text();
    } catch {
      setParseError('Could not read the file.');
      return;
    }
    let parsed;
    try {
      parsed = parseReceivingRows(parseCsv(text));
    } catch (e) {
      setParseError(`Could not parse the CSV: ${(e as Error).message}`);
      return;
    }
    if (parsed.headerError) {
      setState({ rows: [], headerError: parsed.headerError });
      return;
    }
    setDuplicateResolutions(new Map());
    setState({ rows: classifyReceivingRows(parsed.rows, productsQuery.data!, categoryCodes), headerError: null });
  }

  function reset() {
    setState(null);
    setParseError(null);
    setResult(null);
    setDuplicateResolutions(new Map());
  }

  const summary = useMemo(() => {
    const rows = resolvedRows;
    const count = (s: string) => rows.filter((r) => r.status === s).length;
    return {
      total: rows.length,
      match: count('match'),
      mismatch: count('mismatch'),
      new: count('new'),
      errors: count('error'),
      actionable: rows.filter((r) => r.status !== 'error').length,
    };
  }, [resolvedRows]);

  async function runReceive() {
    if (!state || !user || !costCode || !productsQuery.data) return;
    const supplier = suppliersQuery.data?.find((s) => s.id === supplierId) ?? null;
    setIsReceiving(true);
    try {
      setResult(
        await receivingRepo.bulkReceive({
          rows: resolvedRows,
          products: productsQuery.data,
          supplier: supplier ? { id: supplier.id, name: supplier.name } : null,
          cipher: costCode,
          actor: { id: user.id, name: user.displayName },
          categoryCodes,
        }),
      );
    } finally {
      setIsReceiving(false);
    }
  }

  return {
    isLoadingRefs: productsQuery.isLoading || suppliersQuery.isLoading || !costCode,
    loadError: (productsQuery.error ?? suppliersQuery.error ?? null) as Error | null,
    suppliers: suppliersQuery.data ?? [],
    supplierId,
    setSupplierId,
    state,
    duplicateResolutions,
    setDuplicateResolution,
    parseError,
    summary,
    result,
    isReceiving,
    parseFile,
    reset,
    runReceive,
  };
}

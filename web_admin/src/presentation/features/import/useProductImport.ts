import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useProductRepo, useSupplierRepo } from '@/infrastructure/di/container';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { parseCsv } from '@/core/utils/csv';
import { parseImportRows } from '@/domain/products/importRows';
import {
  classifyRows,
  toCreateInput,
  toUpdateInput,
  type ClassifiedRow,
  type RowAction,
} from '@/domain/products/classifyRows';
import type {
  ProductImportOp,
  ProductImportResult,
} from '@/domain/repositories/ProductRepository';

interface ImportState {
  rows: ClassifiedRow[];
  actions: Record<number, RowAction>;
  headerError: string | null;
}

export function useProductImport() {
  const productRepo = useProductRepo();
  const supplierRepo = useSupplierRepo();
  const { data: costCode } = useCostCode();
  const user = useAuthStore((s) => s.user);

  const productsQuery = useQuery({
    queryKey: ['products', 'all'],
    queryFn: () => productRepo.list(),
  });
  const suppliersQuery = useQuery({
    queryKey: ['suppliers', 'all'],
    queryFn: () => supplierRepo.list(),
  });

  const [state, setState] = useState<ImportState | null>(null);
  const [parseError, setParseError] = useState<string | null>(null);
  const [result, setResult] = useState<ProductImportResult | null>(null);
  const [isImporting, setIsImporting] = useState(false);

  const ready = !!costCode && !!productsQuery.data && !!suppliersQuery.data;

  async function parseFile(file: File) {
    setParseError(null);
    setResult(null);
    if (!ready || !costCode) {
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
      parsed = parseImportRows(parseCsv(text), costCode);
    } catch (e) {
      setParseError(`Could not parse the CSV: ${(e as Error).message}`);
      return;
    }
    if (parsed.headerError) {
      setState({ rows: [], actions: {}, headerError: parsed.headerError });
      return;
    }
    const rows = classifyRows(parsed.rows, productsQuery.data!, suppliersQuery.data!);
    const actions: Record<number, RowAction> = {};
    for (const r of rows) actions[r.parsed.rowNumber] = r.defaultAction;
    setState({ rows, actions, headerError: null });
  }

  function setAction(rowNumber: number, action: RowAction) {
    setState((prev) =>
      prev ? { ...prev, actions: { ...prev.actions, [rowNumber]: action } } : prev,
    );
  }

  function reset() {
    setState(null);
    setParseError(null);
    setResult(null);
  }

  const summary = useMemo(() => {
    const rows = state?.rows ?? [];
    let insert = 0;
    let update = 0;
    let skip = 0;
    for (const r of rows) {
      const a = state?.actions[r.parsed.rowNumber] ?? r.defaultAction;
      if (a === 'insert') insert += 1;
      else if (a === 'update') update += 1;
      else skip += 1;
    }
    return {
      total: rows.length,
      insert,
      update,
      skip,
      errors: rows.filter((r) => r.status === 'error').length,
    };
  }, [state]);

  async function runImport() {
    if (!state || !user) return;
    const actor = { id: user.id, name: user.displayName };
    const ops: ProductImportOp[] = [];
    for (const r of state.rows) {
      const action = state.actions[r.parsed.rowNumber] ?? r.defaultAction;
      if (action === 'insert') {
        ops.push({ kind: 'insert', row: r.parsed.rowNumber, input: toCreateInput(r, actor) });
      } else if (action === 'update' && r.matchedProductId) {
        ops.push({
          kind: 'update',
          row: r.parsed.rowNumber,
          id: r.matchedProductId,
          input: toUpdateInput(r, actor),
        });
      }
    }
    setIsImporting(true);
    try {
      setResult(await productRepo.bulkImport(ops, actor.id));
    } finally {
      setIsImporting(false);
    }
  }

  return {
    isLoadingRefs: productsQuery.isLoading || suppliersQuery.isLoading || !costCode,
    loadError: (productsQuery.error ?? suppliersQuery.error ?? null) as Error | null,
    state,
    parseError,
    summary,
    result,
    isImporting,
    parseFile,
    setAction,
    runImport,
    reset,
  };
}

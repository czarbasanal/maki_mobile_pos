import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
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
  type ClassifiedReceivingRow,
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

  const [state, setState] = useState<ReceivingState | null>(null);
  const [supplierId, setSupplierId] = useState<string>('');
  const [parseError, setParseError] = useState<string | null>(null);
  const [result, setResult] = useState<ReceivingResult | null>(null);
  const [isReceiving, setIsReceiving] = useState(false);

  const ready = !!costCode && !!productsQuery.data && !!suppliersQuery.data;

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
    setState({ rows: classifyReceivingRows(parsed.rows, productsQuery.data!), headerError: null });
  }

  function reset() {
    setState(null);
    setParseError(null);
    setResult(null);
  }

  const summary = useMemo(() => {
    const rows = state?.rows ?? [];
    const count = (s: string) => rows.filter((r) => r.status === s).length;
    return {
      total: rows.length,
      match: count('match'),
      mismatch: count('mismatch'),
      new: count('new'),
      errors: count('error'),
      actionable: rows.filter((r) => r.status !== 'error').length,
    };
  }, [state]);

  async function runReceive() {
    if (!state || !user || !costCode || !productsQuery.data) return;
    const supplier = suppliersQuery.data?.find((s) => s.id === supplierId) ?? null;
    setIsReceiving(true);
    try {
      setResult(
        await receivingRepo.bulkReceive({
          rows: state.rows,
          products: productsQuery.data,
          supplier: supplier ? { id: supplier.id, name: supplier.name } : null,
          cipher: costCode,
          actor: { id: user.id, name: user.displayName },
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
    parseError,
    summary,
    result,
    isReceiving,
    parseFile,
    reset,
    runReceive,
  };
}

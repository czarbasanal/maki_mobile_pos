import { useEffect, useState } from 'react';
import { useSupplierRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Supplier } from '@/domain/entities';

export function useSuppliers() {
  const repo = useSupplierRepo();
  return useFirestoreSubscription<Supplier[]>(
    (onData) => repo.watchAll(onData),
    [repo],
  );
}

// One-shot fetch for the form page. Suppliers don't update mid-edit often
// enough to justify a live subscription on top of the dirty form state.
export function useSupplierById(id: string | undefined) {
  const repo = useSupplierRepo();
  const [state, setState] = useState<{
    data: Supplier | null;
    isLoading: boolean;
    error: Error | null;
  }>({ data: null, isLoading: !!id, error: null });

  useEffect(() => {
    let cancelled = false;
    if (!id) {
      setState({ data: null, isLoading: false, error: null });
      return;
    }
    setState((s) => ({ ...s, isLoading: true, error: null }));
    repo
      .getById(id)
      .then((s) => {
        if (cancelled) return;
        setState({ data: s, isLoading: false, error: null });
      })
      .catch((e: Error) => {
        if (cancelled) return;
        setState({ data: null, isLoading: false, error: e });
      });
    return () => {
      cancelled = true;
    };
  }, [repo, id]);

  return state;
}

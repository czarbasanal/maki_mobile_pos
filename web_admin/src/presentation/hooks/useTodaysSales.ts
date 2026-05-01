import { useSaleRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Sale } from '@/domain/entities';

export function useTodaysSales() {
  const repo = useSaleRepo();
  return useFirestoreSubscription<Sale[]>(
    (onData, onError) => repo.watchToday(onData, onError),
    [repo],
  );
}

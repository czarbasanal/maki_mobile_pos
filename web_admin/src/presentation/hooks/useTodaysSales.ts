import { useSaleRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import { shopDateKey } from '@/domain/time/shopTime';
import type { Sale } from '@/domain/entities';

export function useTodaysSales() {
  const repo = useSaleRepo();
  // Day-scoped cache key so a snapshot from before midnight never paints
  // onto the next business day.
  return useFirestoreSubscription<Sale[]>(
    (onData, onError) => repo.watchToday(onData, onError),
    [repo],
    `sales:today:${shopDateKey(new Date())}`,
  );
}

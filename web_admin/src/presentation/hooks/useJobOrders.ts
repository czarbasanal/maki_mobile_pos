import { useJobOrderRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { JobOrder } from '@/domain/entities';

/** Live list of all job orders (newest first). The list page filters to open ones. */
export function useJobOrders() {
  const repo = useJobOrderRepo();
  return useFirestoreSubscription<JobOrder[]>(
    (onData) => repo.watchAll(onData),
    [repo],
    'jobOrders',
  );
}

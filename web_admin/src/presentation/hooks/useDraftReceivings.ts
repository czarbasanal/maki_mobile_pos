import { useReceivingRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Receiving } from '@/domain/entities';

/** Realtime list of all open (draft) receivings, any age, newest first. */
export function useDraftReceivings() {
  const repo = useReceivingRepo();
  return useFirestoreSubscription<Receiving[]>(
    (onData, onError) => repo.watchDrafts(onData, onError),
    [repo],
  );
}

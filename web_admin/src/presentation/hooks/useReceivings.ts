import { useReceivingRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Receiving } from '@/domain/entities';
import type { DateRange } from '@/domain/reports/dateRange';

/** Realtime list of receivings within `range`, newest first. */
export function useReceivings(range: DateRange) {
  const repo = useReceivingRepo();
  return useFirestoreSubscription<Receiving[]>(
    (onData, onError) => repo.watchAll(range, onData, onError),
    [repo, range.start.getTime(), range.end.getTime()],
  );
}

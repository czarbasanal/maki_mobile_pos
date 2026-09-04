import { useAdjustmentReasonRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { AdjustmentReason } from '@/domain/entities';

/** Live adjustment-reason list. Pass includeInactive for the management screen. */
export function useAdjustmentReasons(opts?: { includeInactive?: boolean }) {
  const repo = useAdjustmentReasonRepo();
  const includeInactive = opts?.includeInactive ?? false;
  return useFirestoreSubscription<AdjustmentReason[]>(
    (onData) => repo.watchAll(onData, { includeInactive }),
    [repo, includeInactive],
    `adjustment_reasons:${includeInactive ? 'all' : 'active'}`,
  );
}

/** Active, name-sorted reasons — the adjust-stock dialog's picker source. */
export function useActiveAdjustmentReasons() {
  return useAdjustmentReasons({ includeInactive: false });
}

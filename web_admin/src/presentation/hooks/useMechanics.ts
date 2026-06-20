import { useMechanicRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Mechanic } from '@/domain/entities';

/** Live mechanic list. Pass includeInactive for the management screen. */
export function useMechanics(opts?: { includeInactive?: boolean }) {
  const repo = useMechanicRepo();
  const includeInactive = opts?.includeInactive ?? false;
  return useFirestoreSubscription<Mechanic[]>(
    (onData) => repo.watchAll(onData, { includeInactive }),
    [repo, includeInactive],
  );
}

/** Active, name-sorted mechanics — the POS picker source. */
export function useActiveMechanics() {
  return useMechanics({ includeInactive: false });
}

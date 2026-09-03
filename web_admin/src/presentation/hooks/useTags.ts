import { useTagRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Tag } from '@/domain/entities';

/** Live tag list. Pass includeInactive for the management screen. */
export function useTags(opts?: { includeInactive?: boolean }) {
  const repo = useTagRepo();
  const includeInactive = opts?.includeInactive ?? false;
  return useFirestoreSubscription<Tag[]>(
    (onData) => repo.watchAll(onData, { includeInactive }),
    [repo, includeInactive],
    `product_tags:${includeInactive ? 'all' : 'active'}`,
  );
}

/** Active, name-sorted tags — the chip/filter/picker source. */
export function useActiveTags() {
  return useTags({ includeInactive: false });
}

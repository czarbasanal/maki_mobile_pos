import { useDraftRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Draft } from '@/domain/entities';

/** Live list of all drafts (newest first). The list page filters to open ones. */
export function useDrafts() {
  const repo = useDraftRepo();
  return useFirestoreSubscription<Draft[]>((onData) => repo.watchAll(onData), [repo]);
}

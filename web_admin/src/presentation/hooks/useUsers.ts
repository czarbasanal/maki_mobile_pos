import { useUserRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { User } from '@/domain/entities';

export function useUsers(includeInactive = false) {
  const repo = useUserRepo();
  return useFirestoreSubscription<User[]>(
    (onData) => repo.watchAll(onData, { includeInactive }),
    [repo, includeInactive],
  );
}

export function useUser(id: string | undefined) {
  const repo = useUserRepo();
  return useFirestoreSubscription<User | null>(
    (onData) => {
      if (!id) {
        onData(null);
        return () => {};
      }
      return repo.watchOne(id, onData);
    },
    [repo, id],
  );
}

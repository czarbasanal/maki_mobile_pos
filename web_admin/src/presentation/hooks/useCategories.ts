import { useCategoryRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Category } from '@/domain/entities';
import type { CategoryKind } from '@/domain/categories/categoryKind';

/** Live list for a kind. Pass includeInactive for the management screen. */
export function useCategories(kind: CategoryKind, opts?: { includeInactive?: boolean }) {
  const repo = useCategoryRepo();
  const includeInactive = opts?.includeInactive ?? false;
  return useFirestoreSubscription<Category[]>(
    (onData) => repo.watchAll(kind, onData, { includeInactive }),
    [repo, kind, includeInactive],
  );
}

/** Active, name-sorted entries — the dropdown source for the inventory form. */
export function useActiveCategories(kind: CategoryKind) {
  return useCategories(kind, { includeInactive: false });
}

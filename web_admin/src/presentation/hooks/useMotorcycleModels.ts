import { useMutation } from '@tanstack/react-query';
import { useMotorcycleModelRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import {
  canonicalModelName,
  normalizedModelKey,
  type MotorcycleModel,
} from '@/domain/entities/MotorcycleModel';

/** Active models, name-sorted — the Job Order picker source. */
export function useMotorcycleModels() {
  const repo = useMotorcycleModelRepo();
  return useFirestoreSubscription<MotorcycleModel[]>(
    (onData, onError) => repo.watchActive(onData, onError),
    [repo],
    'motorcycleModels',
  );
}

/** Pick-or-add core (mobile resolveOrCreate parity): reuse an existing row
 *  (best-effort reactivating an archived one), else create; resolves to the
 *  canonical name to snapshot on the ticket. */
export function useResolveOrCreateModel() {
  const repo = useMotorcycleModelRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<string, Error, string>({
    mutationFn: async (rawName) => {
      const canonical = canonicalModelName(rawName);
      if (!canonical) throw new Error('Enter a model name');
      if (!actor) throw new Error('Not signed in');
      const existing = await repo.findByNormalizedKey(normalizedModelKey(rawName));
      if (existing) {
        if (!existing.isActive) {
          // Cashiers are denied the isActive flip by firestore rules — the
          // ticket stores a name snapshot, so resolving to an archived name
          // is still correct; staff can reactivate from the mobile editor.
          try {
            await repo.setActive(existing.id, true, actor.id);
          } catch {
            // Non-fatal.
          }
        }
        return existing.name;
      }
      const created = await repo.create(rawName, actor.id);
      return created.name;
    },
  });
}

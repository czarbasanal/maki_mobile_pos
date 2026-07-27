import { useMutation } from '@tanstack/react-query';
import { useCategoryRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Category } from '@/domain/entities';
import type { CategoryKind } from '@/domain/categories/categoryKind';

export function useCreateCategory(kind: CategoryKind) {
  const repo = useCategoryRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Category, Error, { name: string }>({
    mutationFn: async ({ name }) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(kind, name, actor.id);
    },
  });
}

export function useUpdateCategory(kind: CategoryKind) {
  const repo = useCategoryRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, { id: string; name?: string; isActive?: boolean }>({
    mutationFn: async ({ id, ...patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(kind, id, patch, actor.id);
    },
  });
}

// Hard delete — direct, no deactivate-first gate (lists are admin-managed
// dropdown values; the confirm dialog on ManageListsPage is the guard).
export function useDeleteCategory(kind: CategoryKind) {
  const repo = useCategoryRepo();
  return useMutation<void, Error, { id: string }>({
    mutationFn: async ({ id }) => {
      await repo.delete(kind, id);
    },
  });
}

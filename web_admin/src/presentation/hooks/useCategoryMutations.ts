import { useMutation } from '@tanstack/react-query';
import { useActivityLogRepo, useCategoryRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type Category } from '@/domain/entities';
import { labelForKind, type CategoryKind } from '@/domain/categories/categoryKind';

export function useCreateCategory(kind: CategoryKind) {
  const repo = useCategoryRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Category, Error, { name: string }>({
    mutationFn: async ({ name }) => {
      if (!actor) throw new Error('Not signed in');
      const created = await repo.create(kind, name, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Added ${labelForKind(kind)} entry: ${created.name}`,
        entityId: created.id,
        entityType: 'category',
      }));
      return created;
    },
  });
}

export function useUpdateCategory(kind: CategoryKind) {
  const repo = useCategoryRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, { id: string; name?: string; isActive?: boolean }>({
    mutationFn: async ({ id, ...patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(kind, id, patch, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Updated ${labelForKind(kind)} entry${patch.name ? `: ${patch.name}` : ''}`,
        details: patch.isActive !== undefined ? (patch.isActive ? 'Reactivated' : 'Deactivated') : null,
        entityId: id,
        entityType: 'category',
      }));
    },
  });
}

// Hard delete — direct, no deactivate-first gate (lists are admin-managed
// dropdown values; the confirm dialog on ManageListsPage is the guard).
export function useDeleteCategory(kind: CategoryKind) {
  const repo = useCategoryRepo();
  const activityLogRepo = useActivityLogRepo();
  return useMutation<void, Error, { id: string; name?: string }>({
    mutationFn: async ({ id, name }) => {
      await repo.delete(kind, id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Deleted ${labelForKind(kind)} entry${name ? `: ${name}` : ` ${id}`}`,
        entityId: id,
        entityType: 'category',
      }));
    },
  });
}

import { useMutation } from '@tanstack/react-query';
import { useActivityLogRepo, useTagRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type Tag } from '@/domain/entities';
import type { TagColor } from '@/domain/tags/tagColors';

export function useCreateTag() {
  const repo = useTagRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<
    Tag,
    Error,
    { name: string; color: TagColor; description?: string | null }
  >({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      const created = await repo.create(input, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Added tag: ${created.name}`,
        entityId: created.id,
        entityType: 'tag',
      }));
      return created;
    },
  });
}

export function useUpdateTag() {
  const repo = useTagRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<
    void,
    Error,
    {
      id: string;
      name?: string;
      color?: TagColor;
      description?: string | null;
      isActive?: boolean;
    }
  >({
    mutationFn: async ({ id, ...patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(id, patch, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Updated tag${patch.name ? `: ${patch.name}` : ''}`,
        details: patch.isActive !== undefined ? (patch.isActive ? 'Reactivated' : 'Deactivated') : null,
        entityId: id,
        entityType: 'tag',
      }));
    },
  });
}

// Deactivate-first: the tags page only offers Delete on an already inactive
// row, so no actor/guard check is needed here beyond the repo call.
export function useDeleteTag() {
  const repo = useTagRepo();
  const activityLogRepo = useActivityLogRepo();
  return useMutation<void, Error, { id: string; name?: string }>({
    mutationFn: async ({ id, name }) => {
      await repo.delete(id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Deleted tag${name ? `: ${name}` : ` ${id}`}`,
        entityId: id,
        entityType: 'tag',
      }));
    },
  });
}

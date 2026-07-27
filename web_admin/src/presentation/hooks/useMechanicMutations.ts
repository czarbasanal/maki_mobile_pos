import { useMutation } from '@tanstack/react-query';
import { useActivityLogRepo, useMechanicRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type Mechanic } from '@/domain/entities';

export function useCreateMechanic() {
  const repo = useMechanicRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<
    Mechanic,
    Error,
    { name: string; address?: string | null; contactNumber?: string | null }
  >({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      const created = await repo.create(input, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Added mechanic: ${created.name}`,
        entityId: created.id,
        entityType: 'mechanic',
      }));
      return created;
    },
  });
}

export function useUpdateMechanic() {
  const repo = useMechanicRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<
    void,
    Error,
    {
      id: string;
      name?: string;
      isActive?: boolean;
      address?: string | null;
      contactNumber?: string | null;
    }
  >({
    mutationFn: async ({ id, ...patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(id, patch, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Updated mechanic${patch.name ? `: ${patch.name}` : ''}`,
        details: patch.isActive !== undefined ? (patch.isActive ? 'Reactivated' : 'Deactivated') : null,
        entityId: id,
        entityType: 'mechanic',
      }));
    },
  });
}

// Deactivate-first: the mechanics page only offers Delete on an already
// inactive row, so no actor/guard check is needed here beyond the repo call.
export function useDeleteMechanic() {
  const repo = useMechanicRepo();
  const activityLogRepo = useActivityLogRepo();
  return useMutation<void, Error, { id: string; name?: string }>({
    mutationFn: async ({ id, name }) => {
      await repo.delete(id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Deleted mechanic${name ? `: ${name}` : ` ${id}`}`,
        entityId: id,
        entityType: 'mechanic',
      }));
    },
  });
}

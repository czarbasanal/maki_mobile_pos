import { useMutation } from '@tanstack/react-query';
import { useActivityLogRepo, useAdjustmentReasonRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type AdjustmentReason } from '@/domain/entities';

export function useCreateAdjustmentReason() {
  const repo = useAdjustmentReasonRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<AdjustmentReason, Error, { name: string; requiresNote?: boolean }>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      const created = await repo.create(input, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Added adjustment reason: ${created.name}`,
        entityId: created.id,
        entityType: 'adjustment_reason',
      }));
      return created;
    },
  });
}

export function useUpdateAdjustmentReason() {
  const repo = useAdjustmentReasonRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<
    void,
    Error,
    { id: string; name?: string; requiresNote?: boolean; isActive?: boolean }
  >({
    mutationFn: async ({ id, ...patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(id, patch, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Updated adjustment reason${patch.name ? `: ${patch.name}` : ''}`,
        details: patch.isActive !== undefined ? (patch.isActive ? 'Reactivated' : 'Deactivated') : null,
        entityId: id,
        entityType: 'adjustment_reason',
      }));
    },
  });
}

// Deactivate-first: the page only offers Delete on an already inactive row,
// so no actor/guard check is needed here beyond the repo call.
export function useDeleteAdjustmentReason() {
  const repo = useAdjustmentReasonRepo();
  const activityLogRepo = useActivityLogRepo();
  return useMutation<void, Error, { id: string; name?: string }>({
    mutationFn: async ({ id, name }) => {
      await repo.delete(id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: `Deleted adjustment reason${name ? `: ${name}` : ` ${id}`}`,
        entityId: id,
        entityType: 'adjustment_reason',
      }));
    },
  });
}

export function useSeedAdjustmentReasons() {
  const repo = useAdjustmentReasonRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, void>({
    mutationFn: async () => {
      if (!actor) throw new Error('Not signed in');
      await repo.seedDefaults(actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.settings,
        action: 'Seeded default adjustment reasons',
        entityType: 'adjustment_reason',
      }));
    },
  });
}

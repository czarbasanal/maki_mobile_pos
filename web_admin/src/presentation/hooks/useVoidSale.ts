import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useActivityLogRepo, useSaleRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType } from '@/domain/entities';

// `saleNumber`/`amount` are supplied by the caller (already has the loaded
// Sale in scope on the detail page) rather than re-fetched here, so this
// hook doesn't need its own read of the sale it's about to void.
export function useVoidSale(saleId: string) {
  const repo = useSaleRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { reason: string; saleNumber: string; amount: number }>({
    mutationFn: async ({ reason, saleNumber, amount }) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || actor.email;
      await repo.voidSale(saleId, reason, actor.id, actorName);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.voidSale,
        action: `Voided sale ${saleNumber}`,
        details: `Reason: ${reason}, Amount: ₱${amount.toFixed(2)}`,
        entityId: saleId,
        entityType: 'sale',
        metadata: { saleNumber, reason, amount },
      }));
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['sales', saleId] });
      // Voided sales drop out of report totals — refresh the cached report lists.
      qc.invalidateQueries({ queryKey: ['reports'] });
    },
  });
}

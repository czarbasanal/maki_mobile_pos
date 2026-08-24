// Cashier-side void requests — mirror of mobile's RequestVoidSaleUseCase.
// The repo transaction owns the duplicate lock; this hook owns the log
// (verbatim mobile strings) and the pending-state cache.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useActivityLogRepo, useVoidRequestRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, saleGrandTotal, type Sale } from '@/domain/entities';
import { voidRequestItemsSummary } from '@/domain/sales/voiding';

export function usePendingVoidRequest(saleId: string) {
  const repo = useVoidRequestRepo();
  return useQuery({
    queryKey: ['voidRequestPending', saleId],
    queryFn: () => repo.hasPendingForSale(saleId),
    // Mobile streams this; on web a focus refetch is the accepted
    // approximation for "the admin resolved it on their phone".
    refetchOnWindowFocus: true,
  });
}

export function useRequestVoid(saleId: string) {
  const repo = useVoidRequestRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { sale: Sale; reason: string }>({
    mutationFn: async ({ sale, reason }) => {
      if (!actor) throw new Error('Not signed in');
      const amount = saleGrandTotal(sale);
      await repo.createRequest({
        saleId,
        saleNumber: sale.saleNumber,
        saleGrandTotal: amount,
        requestedBy: actor.id,
        requestedByName: actor.displayName,
        requestedByRole: actor.role,
        reason,
        itemsSummary: voidRequestItemsSummary(sale),
      });
      logActivity(activityLogRepo, () => ({
        type: ActivityType.voidSale,
        action: `Requested void for sale ${sale.saleNumber}`,
        details: `Reason: ${reason}, Amount: ₱${amount.toFixed(2)}`,
        entityId: saleId,
        entityType: 'sale',
      }));
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['voidRequestPending', saleId] });
    },
  });
}

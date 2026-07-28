import { useMutation } from '@tanstack/react-query';
import { useActivityLogRepo, useSaleRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, saleGrandTotal, saleTotalItemCount, type Sale } from '@/domain/entities';
import { buildSaleInput, type CheckoutInput } from './buildSaleInput';

export type { CheckoutInput };

// Covers both a plain new sale AND a Job-Order bill-out (the create()
// transaction converts the job order internally when input.jobOrderId is set) — one
// log site for both, since from here it's the same write.
export function useCheckout() {
  const repo = useSaleRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Sale, Error, CheckoutInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      const sale = await repo.create(buildSaleInput(input, actor), actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.sale,
        action: `Completed sale ${sale.saleNumber}`,
        details: `${saleTotalItemCount(sale)} items, total: ₱${saleGrandTotal(sale).toFixed(2)}`,
        entityId: sale.id,
        entityType: 'sale',
        metadata: {
          saleNumber: sale.saleNumber,
          amount: saleGrandTotal(sale),
          itemCount: saleTotalItemCount(sale),
        },
      }));
      return sale;
    },
  });
}

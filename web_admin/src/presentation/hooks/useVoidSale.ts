import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';

export function useVoidSale(saleId: string) {
  const repo = useSaleRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { reason: string }>({
    mutationFn: async ({ reason }) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || actor.email;
      await repo.voidSale(saleId, reason, actor.id, actorName);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['sales', saleId] });
      // Voided sales drop out of report totals — refresh the cached report lists.
      qc.invalidateQueries({ queryKey: ['reports'] });
    },
  });
}

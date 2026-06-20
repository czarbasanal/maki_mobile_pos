import { useMutation } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Sale } from '@/domain/entities';
import { buildSaleInput, type CheckoutInput } from './buildSaleInput';

export type { CheckoutInput };

export function useCheckout() {
  const repo = useSaleRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Sale, Error, CheckoutInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(buildSaleInput(input, actor), actor.id);
    },
  });
}

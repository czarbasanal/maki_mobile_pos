import { useMutation } from '@tanstack/react-query';
import { useReceivingRepo } from '@/infrastructure/di/container';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Receiving } from '@/domain/entities';
import type { ReceivingInput } from '@/domain/repositories/ReceivingRepository';

export function useCreateReceiving() {
  const repo = useReceivingRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Receiving, Error, ReceivingInput>({
    mutationFn: (input) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(input, actor.id);
    },
  });
}

export function useUpdateReceiving() {
  const repo = useReceivingRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, { id: string; input: ReceivingInput }>({
    mutationFn: ({ id, input }) => {
      if (!actor) throw new Error('Not signed in');
      return repo.update(id, input, actor.id);
    },
  });
}

export function useCompleteReceiving() {
  const repo = useReceivingRepo();
  const actor = useAuthStore((s) => s.user);
  const { data: cipher } = useCostCode();
  return useMutation<void, Error, string>({
    mutationFn: (id) => {
      if (!actor) throw new Error('Not signed in');
      if (!cipher) throw new Error('Cost-code settings still loading');
      return repo.complete(id, { id: actor.id, name: actor.displayName }, cipher);
    },
  });
}

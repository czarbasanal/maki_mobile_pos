import { useMutation } from '@tanstack/react-query';
import { useMechanicRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Mechanic } from '@/domain/entities';

export function useCreateMechanic() {
  const repo = useMechanicRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Mechanic, Error, { name: string }>({
    mutationFn: async ({ name }) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(name, actor.id);
    },
  });
}

export function useUpdateMechanic() {
  const repo = useMechanicRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, { id: string; name?: string; isActive?: boolean }>({
    mutationFn: async ({ id, ...patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(id, patch, actor.id);
    },
  });
}

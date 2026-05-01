import { useMutation } from '@tanstack/react-query';
import { useAuthRepo, useCostCodeRepo } from '@/infrastructure/di/container';
import type { CostCode } from '@/domain/entities';

interface UpdateCostCodeInput {
  mapping: Omit<CostCode, 'updatedAt' | 'updatedBy'>;
  // Caller's password — re-authenticated before the write to mirror the
  // Flutter PasswordDialog flow. The cost-code mapping is sensitive, so we
  // require fresh credentials on every save.
  password: string;
}

export function useUpdateCostCode() {
  const authRepo = useAuthRepo();
  const costCodeRepo = useCostCodeRepo();

  return useMutation<void, Error, UpdateCostCodeInput>({
    mutationFn: async ({ mapping, password }) => {
      const ok = await authRepo.verifyPassword(password);
      if (!ok) throw new Error('Incorrect password');
      const actorId = authRepo.currentUserId;
      if (!actorId) throw new Error('Not signed in');
      await costCodeRepo.update(mapping, actorId);
    },
  });
}

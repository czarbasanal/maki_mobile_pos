import { useMutation } from '@tanstack/react-query';
import { useActivityLogRepo, useReceivingRepo } from '@/infrastructure/di/container';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type Receiving } from '@/domain/entities';
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
  return useMutation<
    void,
    Error,
    { id: string; input: ReceivingInput; expectedVersion: number }
  >({
    mutationFn: ({ id, input, expectedVersion }) => {
      if (!actor) throw new Error('Not signed in');
      return repo.update(id, input, actor.id, expectedVersion);
    },
  });
}

export interface CompleteReceivingInput {
  id: string;
  // Caller already has these in scope (the entry form it just saved as a
  // draft) — repo.complete() returns void, so they're passed through rather
  // than re-fetched just for the log line.
  referenceNumber: string;
  itemCount: number;
  totalCost: number;
  supplierName: string | null;
}

export function useCompleteReceiving() {
  const repo = useReceivingRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const { data: cipher } = useCostCode();
  return useMutation<void, Error, CompleteReceivingInput>({
    mutationFn: async ({ id, referenceNumber, itemCount, totalCost, supplierName }) => {
      if (!actor) throw new Error('Not signed in');
      if (!cipher) throw new Error('Cost-code settings still loading');
      await repo.complete(id, { id: actor.id, name: actor.displayName }, cipher);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.receiving,
        action: `Completed receiving ${referenceNumber}`,
        details: `${itemCount} items, total cost: ₱${totalCost.toFixed(2)}${supplierName ? `, Supplier: ${supplierName}` : ''}`,
        entityId: id,
        entityType: 'receiving',
        metadata: { referenceNumber, itemCount, totalCost, supplierName },
      }));
    },
  });
}

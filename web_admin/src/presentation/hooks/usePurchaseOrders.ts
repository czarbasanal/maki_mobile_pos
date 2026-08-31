import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  useActivityLogRepo,
  usePurchaseOrderRepo,
} from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type PurchaseOrder } from '@/domain/entities';
import type { PurchaseOrderInput } from '@/domain/repositories/PurchaseOrderRepository';

export function usePurchaseOrders() {
  const repo = usePurchaseOrderRepo();
  return useFirestoreSubscription<PurchaseOrder[]>(
    (onData, onError) => repo.watchAll(onData, onError),
    [repo],
  );
}

export function usePurchaseOrder(id: string) {
  const repo = usePurchaseOrderRepo();
  return useQuery({
    queryKey: ['purchaseOrder', id],
    queryFn: () => repo.getById(id),
    enabled: id.length > 0,
  });
}

/** Save as draft, or Confirm — the same write with a different status. */
export function useCreatePurchaseOrder() {
  const repo = usePurchaseOrderRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<
    PurchaseOrder,
    Error,
    Omit<PurchaseOrderInput, 'createdBy' | 'createdByName'>
  >({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      const created = await repo.create({
        ...input,
        createdBy: actor.id,
        createdByName: actor.displayName.trim() || actor.email,
      });
      logActivity(activityLogRepo, () => ({
        type: ActivityType.other,
        action: `${input.status === 'ordered' ? 'Confirmed' : 'Drafted'} purchase order ${created.referenceNumber}`,
        details: `${created.totalQuantity} units, ₱${created.totalCost.toFixed(2)}`,
        entityId: created.id,
        entityType: 'purchase_order',
      }));
      return created;
    },
  });
}

export function useUpdatePurchaseOrder() {
  const repo = usePurchaseOrderRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<
    void,
    Error,
    { id: string; patch: Parameters<typeof repo.update>[1] }
  >({
    mutationFn: ({ id, patch }) => {
      if (!actor) throw new Error('Not signed in');
      return repo.update(id, patch, actor.id);
    },
    onSuccess: (_d, { id }) =>
      qc.invalidateQueries({ queryKey: ['purchaseOrder', id] }),
  });
}

export function useCancelPurchaseOrder() {
  const repo = usePurchaseOrderRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, PurchaseOrder>({
    mutationFn: async (po) => {
      if (!actor) throw new Error('Not signed in');
      await repo.cancel(po.id, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.other,
        action: `Cancelled purchase order ${po.referenceNumber}`,
        entityId: po.id,
        entityType: 'purchase_order',
      }));
    },
    onSuccess: (_d, po) =>
      qc.invalidateQueries({ queryKey: ['purchaseOrder', po.id] }),
  });
}

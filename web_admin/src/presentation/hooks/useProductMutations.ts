import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { ProductUpdateInput } from '@/domain/repositories/ProductRepository';

export interface UpdateProductInput {
  id: string;
  oldSku: string;
  patch: ProductUpdateInput;
  /** Set when cost and/or price changed; triggers a best-effort price_history write. */
  priceChange: { price: number; cost: number; reason: string } | null;
}

export function useUpdateProduct() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, UpdateProductInput>({
    mutationFn: async ({ id, oldSku, patch, priceChange }) => {
      if (!actor) throw new Error('Not signed in');
      const fullPatch: ProductUpdateInput = { ...patch, updatedByName: (actor.displayName.trim() || null) };
      const skuChanged = fullPatch.sku !== undefined && fullPatch.sku !== oldSku;

      if (skuChanged) {
        const newSku = fullPatch.sku as string;
        if (await repo.skuExists(newSku, id)) {
          throw new Error('A product with this SKU already exists');
        }
        await repo.updateProductWithSku(id, fullPatch, oldSku, newSku, actor.id, (actor.displayName.trim() || null));
      } else {
        await repo.update(id, fullPatch, actor.id);
      }

      if (priceChange) {
        try {
          await repo.recordPriceChange(id, {
            price: priceChange.price,
            cost: priceChange.cost,
            changedBy: actor.id,
            reason: priceChange.reason,
          });
        } catch {
          // best-effort, mirroring mobile — never fail the save on a history write
        }
      }

      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useAdjustStock() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { id: string; delta: number }>({
    mutationFn: async ({ id, delta }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.adjustStock(id, delta, actor.id, (actor.displayName.trim() || null));
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useSetStock() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { id: string; quantity: number }>({
    mutationFn: async ({ id, quantity }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.setStock(id, quantity, actor.id, (actor.displayName.trim() || null));
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useDeactivateProduct() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, string>({
    mutationFn: async (id) => {
      if (!actor) throw new Error('Not signed in');
      await repo.deactivate(id, actor.id, (actor.displayName.trim() || null));
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useReactivateProduct() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, string>({
    mutationFn: async (id) => {
      if (!actor) throw new Error('Not signed in');
      await repo.reactivate(id, actor.id, (actor.displayName.trim() || null));
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

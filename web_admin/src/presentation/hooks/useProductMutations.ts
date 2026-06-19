import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { ProductCreateInput, ProductUpdateInput } from '@/domain/repositories/ProductRepository';
import type { Product } from '@/domain/entities';
import { diffBarcodeClaims } from '@/domain/products/barcodes';

export interface UpdateProductInput {
  id: string;
  oldSku: string;
  oldBarcodes: string[];
  patch: ProductUpdateInput;
  /** Set when cost and/or price changed; triggers a best-effort price_history write. */
  priceChange: { price: number; cost: number; reason: string } | null;
}

export function useUpdateProduct() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, UpdateProductInput>({
    mutationFn: async ({ id, oldSku, oldBarcodes, patch, priceChange }) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || null;
      const fullPatch: ProductUpdateInput = { ...patch, updatedByName: actorName };
      const newSku = (fullPatch.sku ?? oldSku) as string;
      const skuChanged = fullPatch.sku !== undefined && fullPatch.sku !== oldSku;
      const newBarcodes = (fullPatch.barcodes ?? oldBarcodes) as string[];
      const { added, removed } = diffBarcodeClaims(oldBarcodes, newBarcodes);
      const barcodesChanged = added.length > 0 || removed.length > 0;

      if (skuChanged || barcodesChanged) {
        if (skuChanged && (await repo.skuExists(newSku, id))) {
          throw new Error('A product with this SKU already exists');
        }
        for (const code of added) {
          if (await repo.barcodeExists(code, id)) {
            throw new Error('A product with this barcode already exists');
          }
        }
        await repo.updateProductWithClaims(
          id,
          fullPatch,
          { old: oldSku, next: newSku, changed: skuChanged },
          { old: oldBarcodes, next: newBarcodes },
          actor.id,
          actorName,
        );
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

/** Fields the create form supplies; the hook assembles the rest of ProductCreateInput. */
export interface CreateProductInput {
  sku: string;
  name: string;
  costCode: string;
  cost: number;
  price: number;
  quantity: number;
  reorderLevel: number;
  unit: string;
  supplierId: string | null;
  supplierName: string | null;
  barcodes: string[];
  category: string | null;
  notes: string | null;
}

export function useCreateProduct() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<Product, Error, CreateProductInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      if (await repo.skuExists(input.sku)) {
        throw new Error('A product with this SKU already exists');
      }
      for (const code of input.barcodes) {
        if (await repo.barcodeExists(code)) {
          throw new Error('A product with this barcode already exists');
        }
      }
      const actorName = actor.displayName.trim() || null;
      const created = await repo.create(
        {
          ...input,
          isActive: true,
          createdBy: actor.id,
          updatedBy: actor.id,
          createdByName: actorName,
          updatedByName: actorName,
          baseSku: null,
          variationNumber: null,
          imageUrl: null,
        } as ProductCreateInput,
        actor.id,
      );
      try {
        await repo.recordPriceChange(created.id, {
          price: input.price,
          cost: input.cost,
          changedBy: actor.id,
          reason: 'Initial price',
        });
      } catch {
        // best-effort; never fail the create on a history write
      }
      qc.invalidateQueries({ queryKey: ['product', created.id] });
      return created;
    },
  });
}

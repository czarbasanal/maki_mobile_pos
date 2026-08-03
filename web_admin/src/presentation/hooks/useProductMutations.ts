import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useActivityLogRepo, useProductRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import type { ProductCreateInput, ProductUpdateInput } from '@/domain/repositories/ProductRepository';
import { ActivityType, type Product, type SellingOption } from '@/domain/entities';
import { UserRole } from '@/domain/enums';
import { diffBarcodeClaims } from '@/domain/products/barcodes';
import { matchesAutoPattern } from '@/domain/products/sku';
import { uploadProductImage, deleteProductImage } from '@/infrastructure/firebase/productImageStorage';

export interface UpdateProductInput {
  id: string;
  oldSku: string;
  oldBarcodes: string[];
  patch: ProductUpdateInput;
  /** Set when cost and/or price changed; triggers a best-effort price_history write. */
  priceChange: { price: number; cost: number; reason: string } | null;
  /** Image change to apply before the doc write. Omitted = keep the current image. */
  image?: { kind: 'keep' } | { kind: 'replace'; blob: Blob } | { kind: 'remove' };
}

export function useUpdateProduct() {
  const repo = useProductRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, UpdateProductInput>({
    mutationFn: async ({ id, oldSku, oldBarcodes, patch, priceChange, image }) => {
      if (!actor) throw new Error('Not signed in');
      // sellingOptions sets prices, so it's admin-only in firestore.rules —
      // only an admin actor's write payload may include the key (Task 13).
      const includeSellingOptions = actor.role === UserRole.admin;
      const actorName = actor.displayName.trim() || null;
      const fullPatch: ProductUpdateInput = { ...patch, updatedByName: actorName };
      if (image?.kind === 'replace') {
        fullPatch.imageUrl = await uploadProductImage(id, image.blob);
      } else if (image?.kind === 'remove') {
        await deleteProductImage(id);
        fullPatch.imageUrl = null;
      }
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
          includeSellingOptions,
        );
      } else {
        await repo.update(id, fullPatch, actor.id, includeSellingOptions);
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

      logActivity(activityLogRepo, () => ({
        type: ActivityType.inventory,
        action: `Updated product: ${fullPatch.name ?? id}`,
        details: `SKU ${newSku}`,
        entityId: id,
        entityType: 'product',
      }));

      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useAdjustStock() {
  const repo = useProductRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { id: string; delta: number; productName: string; sku: string; oldQuantity: number }>({
    mutationFn: async ({ id, delta, productName, sku, oldQuantity }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.adjustStock(id, delta, actor.id, (actor.displayName.trim() || null));
      const newQuantity = oldQuantity + delta;
      logActivity(activityLogRepo, () => ({
        type: ActivityType.stockAdjustment,
        action: `Adjusted stock for ${productName}`,
        details: `${oldQuantity} → ${newQuantity} (${delta >= 0 ? '+' : ''}${delta})`,
        entityId: id,
        entityType: 'product',
        metadata: { sku, oldQuantity, newQuantity, change: delta },
      }));
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useSetStock() {
  const repo = useProductRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { id: string; quantity: number; productName: string; sku: string; oldQuantity: number }>({
    mutationFn: async ({ id, quantity, productName, sku, oldQuantity }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.setStock(id, quantity, actor.id, (actor.displayName.trim() || null));
      logActivity(activityLogRepo, () => ({
        type: ActivityType.stockAdjustment,
        action: `Adjusted stock for ${productName}`,
        details: `${oldQuantity} → ${quantity} (${quantity - oldQuantity >= 0 ? '+' : ''}${quantity - oldQuantity})`,
        entityId: id,
        entityType: 'product',
        metadata: { sku, oldQuantity, newQuantity: quantity, change: quantity - oldQuantity },
      }));
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useDeactivateProduct() {
  const repo = useProductRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { id: string; name: string; sku: string }>({
    mutationFn: async ({ id, name, sku }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.deactivate(id, actor.id, (actor.displayName.trim() || null));
      logActivity(activityLogRepo, () => ({
        type: ActivityType.inventory,
        action: `Deactivated product: ${name}`,
        details: `SKU ${sku}`,
        entityId: id,
        entityType: 'product',
      }));
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useReactivateProduct() {
  const repo = useProductRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { id: string; name: string; sku: string }>({
    mutationFn: async ({ id, name, sku }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.reactivate(id, actor.id, (actor.displayName.trim() || null));
      logActivity(activityLogRepo, () => ({
        type: ActivityType.inventory,
        action: `Reactivated product: ${name}`,
        details: `SKU ${sku}`,
        entityId: id,
        entityType: 'product',
      }));
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
  imageBlob?: Blob | null;
  /** Unrestricted at creation — matching how `price` already works. Left
   *  optional here (rather than mirroring `ProductCreateInput`'s required
   *  `SellingOption[]`) because most create-mode callers never touch it;
   *  `buildProductWrites` defaults a missing value to `[]` at the write
   *  layer, so this hook doesn't need to. */
  sellingOptions?: SellingOption[];
  /** Set when a coded category drove the SKU field; relied on by the create
   *  transaction's peek-then-claim scan (see FirestoreProductRepository.create).
   *  Ignored (falls back to the plain manual path) unless `sku` still matches
   *  that code's auto pattern. */
  autoSkuCategoryCode?: string;
}

export function useCreateProduct() {
  const repo = useProductRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<Product, Error, CreateProductInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      const autoMode =
        input.autoSkuCategoryCode !== undefined &&
        matchesAutoPattern(input.sku, input.autoSkuCategoryCode);
      // The auto path relies on the create transaction's own claim-read scan
      // (it may advance past `input.sku`) — a pre-check here would just be a
      // stale, redundant read. Manual SKUs still get the pre-check so the
      // form can surface a duplicate-SKU error before attempting the write.
      if (!autoMode && (await repo.skuExists(input.sku))) {
        throw new Error('A product with this SKU already exists');
      }
      for (const code of input.barcodes) {
        if (await repo.barcodeExists(code)) {
          throw new Error('A product with this barcode already exists');
        }
      }
      const actorName = actor.displayName.trim() || null;
      const { imageBlob, autoSkuCategoryCode, ...fields } = input;
      const created = await repo.create(
        {
          ...fields,
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
        autoMode ? autoSkuCategoryCode : undefined,
      );
      if (imageBlob) {
        try {
          const imageUrl = await uploadProductImage(created.id, imageBlob);
          await repo.update(created.id, { imageUrl }, actor.id);
          created.imageUrl = imageUrl;
        } catch {
          // best-effort — the product is already created + SKU-claimed; a failed
          // image upload shouldn't strand it (the image can be added via edit).
        }
      }
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
      logActivity(activityLogRepo, () => ({
        type: ActivityType.inventory,
        action: `Created product: ${created.name}`,
        details: `SKU ${created.sku} • ₱${created.price.toFixed(2)}`,
        entityId: created.id,
        entityType: 'product',
      }));
      qc.invalidateQueries({ queryKey: ['product', created.id] });
      return created;
    },
  });
}

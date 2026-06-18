import {
  collection,
  doc,
  serverTimestamp,
  type DocumentData,
  type DocumentReference,
  type Firestore,
} from 'firebase/firestore';
import type { ProductCreateInput } from '@/domain/repositories/ProductRepository';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { generateSearchKeywords } from '@/domain/products/searchKeywords';
import { isValidSku, normalizeSku } from '@/domain/products/sku';

export interface ProductWrites {
  productRef: DocumentReference;
  productData: DocumentData;
  claimRef: DocumentReference;
  claimData: DocumentData;
}

/**
 * Builds — without executing — the two writes that create a product: the
 * `products/{id}` doc and its `product_skus/{normalizedSku}` uniqueness claim.
 * Shared by `FirestoreProductRepository.create` and the receiving transaction so
 * the claim shape + product-doc shape live in exactly one place. The caller
 * supplies the product id (so it can be allocated up front and reused across a
 * multi-write transaction) and is responsible for the claim-existence check.
 */
export function buildProductWrites(
  db: Firestore,
  input: ProductCreateInput,
  actorId: string,
  productId: string,
): ProductWrites {
  // The SKU becomes a product_skus claim doc-id; reject SKUs that can't form a
  // valid doc-id ('/', empty) with a clear message rather than an opaque error.
  if (!isValidSku(normalizeSku(input.sku))) {
    throw new Error(`Invalid SKU "${input.sku}" — use letters, numbers, and hyphens only.`);
  }
  const productRef = doc(db, FirestoreCollections.products, productId);
  const claimRef = doc(db, FirestoreCollections.productSkus, normalizeSku(input.sku));
  const searchKeywords =
    input.searchKeywords ?? generateSearchKeywords([input.sku, input.name, input.category]);
  return {
    productRef,
    productData: {
      sku: input.sku,
      name: input.name,
      costCode: input.costCode,
      cost: input.cost,
      price: input.price,
      quantity: input.quantity,
      reorderLevel: input.reorderLevel,
      unit: input.unit,
      supplierId: input.supplierId,
      supplierName: input.supplierName,
      isActive: input.isActive,
      createdBy: actorId,
      updatedBy: actorId,
      createdByName: input.createdByName,
      // Mirror createdByName onto updatedByName at create, like Flutter.
      updatedByName: input.createdByName,
      searchKeywords,
      baseSku: input.baseSku,
      variationNumber: input.variationNumber,
      barcode: input.barcode,
      category: input.category,
      imageUrl: input.imageUrl,
      notes: input.notes,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
    claimRef,
    claimData: {
      sku: input.sku,
      productId,
      claimedBy: actorId,
      claimedAt: serverTimestamp(),
    },
  };
}

/** Generates a fresh product doc id (used to allocate ids before a transaction). */
export function newProductId(db: Firestore): string {
  return doc(collection(db, FirestoreCollections.products)).id;
}

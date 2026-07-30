import {
  collection,
  deleteField,
  doc,
  serverTimestamp,
  type DocumentData,
  type DocumentReference,
  type Firestore,
} from 'firebase/firestore';
import type {
  ProductCreateInput,
  ProductUpdateInput,
} from '@/domain/repositories/ProductRepository';
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
      barcodes: input.barcodes,
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

/**
 * Builds the update payload for `products/{id}` — the web mirror of
 * `ProductModel.toUpdateMap` on mobile. Shared by `FirestoreProductRepository`'s
 * `update` and `updateProductWithClaims` so the field-shape lives in one place.
 *
 * [includeSellingOptions] must stay false for non-admin writers. Selling
 * options set prices and are admin-only in firestore.rules; because this map
 * only writes fields the caller actually supplied (`input[key] !== undefined`),
 * a doc missing `sellingOptions` would have the key ADDED the moment any
 * caller passes it, landing in `diff().affectedKeys()` and getting an
 * otherwise-legitimate staff/cashier edit rejected — same hazard the mobile
 * `toUpdateMap` doc comment and the cashier rules-comment both describe.
 * Callers must only pass true on a confirmed admin path.
 */
export function buildProductUpdate(
  input: ProductUpdateInput,
  actorId: string,
  includeSellingOptions = false,
): Record<string, unknown> {
  const data: Record<string, unknown> = {
    updatedBy: actorId,
    updatedAt: serverTimestamp(),
  };
  const valueFields = [
    'sku', 'name', 'costCode', 'cost', 'price', 'quantity', 'reorderLevel',
    'unit', 'supplierId', 'supplierName', 'isActive', 'baseSku',
    'variationNumber', 'barcodes', 'category', 'imageUrl', 'notes', 'updatedByName',
  ] as const;
  for (const key of valueFields) {
    if (input[key] !== undefined) data[key] = input[key];
  }
  if (includeSellingOptions && input.sellingOptions !== undefined) {
    data.sellingOptions = input.sellingOptions;
  }
  // Drop the legacy singular `barcode` whenever we write the array form.
  if (input.barcodes !== undefined) data.barcode = deleteField();
  // Keywords only need rebuilding if the name changes (import never does this;
  // a future inventory edit might).
  if (input.name !== undefined) {
    data.searchKeywords = generateSearchKeywords([
      input.sku ?? input.name,
      input.name,
      input.category ?? null,
    ]);
  }
  return data;
}

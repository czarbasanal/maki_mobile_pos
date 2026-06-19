// Read-side implementation of ProductRepository. Phase 2 needs watchAll (for
// the dashboard inventory-status counts). Write paths land in phase 7.

import {
  addDoc,
  collection,
  deleteField,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  updateDoc,
  where,
  type Firestore,
} from 'firebase/firestore';
import type { ProductRepository } from '@/domain/repositories/ProductRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Product } from '@/domain/entities';
import { FirestoreCollections, Subcollections } from '@/infrastructure/firebase/collections';
import { productConverter } from '@/data/converters/productConverter';
import { toDate } from '@/data/converters/timestamps';
import { generateSearchKeywords } from '@/domain/products/searchKeywords';
import { normalizeSku, normalizeBarcode, isClaimableBarcode } from '@/domain/products/sku';
import { diffBarcodeClaims } from '@/domain/products/barcodes';
import { buildProductWrites, newProductId } from '@/data/products/productWrites';
import { DuplicateSkuError, DuplicateBarcodeError } from '@/data/errors';
import type {
  PriceHistoryEntry,
  ProductCreateInput,
  ProductUpdateInput,
} from '@/domain/repositories/ProductRepository';

export class FirestoreProductRepository implements ProductRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.products).withConverter(productConverter);
  }

  async getById(id: string): Promise<Product | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.products, id).withConverter(productConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  async getBySku(sku: string): Promise<Product | null> {
    const snap = await getDocs(query(this.col(), where('sku', '==', sku)));
    return snap.empty ? null : snap.docs[0].data();
  }

  async getByBarcode(barcode: string): Promise<Product | null> {
    const code = normalizeBarcode(barcode);
    const byArray = await getDocs(query(this.col(), where('barcodes', 'array-contains', code)));
    if (!byArray.empty) return byArray.docs[0].data();
    const byLegacy = await getDocs(query(this.col(), where('barcode', '==', code)));
    return byLegacy.empty ? null : byLegacy.docs[0].data();
  }

  async list(): Promise<Product[]> {
    const snap = await getDocs(query(this.col(), orderBy('name')));
    return snap.docs.map((d) => d.data());
  }

  watchAll(callback: (products: Product[]) => void): Unsubscribe {
    return onSnapshot(query(this.col(), orderBy('name')), (snap) => {
      callback(snap.docs.map((d) => d.data()));
    });
  }

  watchOne(id: string, callback: (product: Product | null) => void): Unsubscribe {
    return onSnapshot(
      doc(this.db, FirestoreCollections.products, id).withConverter(productConverter),
      (snap) => callback(snap.exists() ? snap.data() : null),
    );
  }

  async search(queryText: string): Promise<Product[]> {
    if (!queryText.trim()) return this.list();
    const snap = await getDocs(
      query(this.col(), where('searchKeywords', 'array-contains', queryText.toLowerCase())),
    );
    return snap.docs.map((d) => d.data());
  }

  async listBySupplier(supplierId: string): Promise<Product[]> {
    const snap = await getDocs(query(this.col(), where('supplierId', '==', supplierId)));
    return snap.docs.map((d) => d.data());
  }

  async listLowStock(): Promise<Product[]> {
    // Firestore can't compare two fields directly; fetch active products and
    // filter client-side. Cheap for stock counts, fine for the dashboard.
    const snap = await getDocs(query(this.col(), where('isActive', '==', true)));
    return snap.docs.map((d) => d.data()).filter((p) => p.quantity <= p.reorderLevel);
  }

  async skuExists(sku: string, excludeId?: string): Promise<boolean> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku)),
    );
    if (!snap.exists()) return false;
    if (excludeId === undefined) return true;
    return (snap.data() as { productId?: string }).productId !== excludeId;
  }

  async countSkuVariations(baseSku: string): Promise<number> {
    const snap = await getDocs(query(this.col(), where('baseSku', '==', baseSku)));
    return snap.size;
  }

  async updateProductWithClaims(
    id: string,
    input: ProductUpdateInput,
    sku: { old: string; next: string; changed: boolean },
    barcode: { old: string[]; next: string[] },
    actorId: string,
    actorName: string | null,
  ): Promise<void> {
    // Variation children (baseSku == old) must be read OUTSIDE the transaction
    // (Firestore transactions can't run queries) — only needed on a SKU rename.
    const children = sku.changed
      ? await getDocs(
          query(
            collection(this.db, FirestoreCollections.products),
            where('baseSku', '==', sku.old),
          ),
        )
      : null;

    const { added, removed } = diffBarcodeClaims(barcode.old, barcode.next);
    for (const key of added) {
      if (!isClaimableBarcode(key)) {
        throw new Error(`Invalid barcode "${key}" — it can't contain "/" or be "." or "..".`);
      }
    }
    const newSkuClaimRef = doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku.next));
    const addedRefs = added.map((k) => doc(this.db, FirestoreCollections.productBarcodes, k));
    const removedRefs = removed.map((k) => doc(this.db, FirestoreCollections.productBarcodes, k));

    // Move the SKU claim and/or diff the barcode claims, update the parent, and
    // re-point every child's baseSku — atomically, so the group never observes
    // a dangling link.
    await runTransaction(this.db, async (tx) => {
      // Reads first (Firestore transactions require reads-before-writes).
      const newSkuClaim = sku.changed ? await tx.get(newSkuClaimRef) : null;
      const addedClaims = await Promise.all(addedRefs.map((r) => tx.get(r)));
      if (
        sku.changed &&
        newSkuClaim!.exists() &&
        (newSkuClaim!.data() as { productId?: string }).productId !== id
      ) {
        throw new DuplicateSkuError();
      }
      if (
        addedClaims.some(
          (c) => c.exists() && (c.data() as { productId?: string }).productId !== id,
        )
      ) {
        throw new DuplicateBarcodeError();
      }
      // Product doc: reuse updateData so searchKeywords rebuild + whitelist
      // apply. input already carries the new sku + barcodes from the form patch.
      tx.update(
        doc(this.db, FirestoreCollections.products, id),
        this.updateData(input, actorId),
      );
      if (sku.changed) {
        for (const child of children!.docs) {
          tx.update(child.ref, {
            baseSku: sku.next,
            updatedBy: actorId,
            updatedByName: actorName,
            updatedAt: serverTimestamp(),
          });
        }
        // delete-then-set is safe even when old == next (case-only rename):
        // same ref → the set wins, re-keying the claim's sku field.
        tx.delete(doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku.old)));
        tx.set(newSkuClaimRef, {
          sku: sku.next,
          productId: id,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      }
      removedRefs.forEach((r) => tx.delete(r));
      addedRefs.forEach((r, i) => {
        tx.set(r, {
          barcode: added[i],
          productId: id,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      });
    });
  }

  async barcodeExists(barcode: string, excludeProductId?: string): Promise<boolean> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.productBarcodes, normalizeBarcode(barcode)),
    );
    if (!snap.exists()) return false;
    if (excludeProductId === undefined) return true;
    return (snap.data() as { productId?: string }).productId !== excludeProductId;
  }

  // Write methods land in phase 7.
  async create(input: ProductCreateInput, actorId: string): Promise<Product> {
    const productId = newProductId(this.db);
    const { productRef, productData, claimRef, claimData } = buildProductWrites(
      this.db,
      input,
      actorId,
      productId,
    );
    // Unique, normalized, non-empty barcode keys (reuse the diff helper: every
    // code is "added" vs an empty old set).
    const barcodeKeys = diffBarcodeClaims([], input.barcodes).added;
    for (const key of barcodeKeys) {
      if (!isClaimableBarcode(key)) {
        throw new Error(`Invalid barcode "${key}" — it can't contain "/" or be "." or "..".`);
      }
    }
    const barcodeClaimRefs = barcodeKeys.map((k) =>
      doc(this.db, FirestoreCollections.productBarcodes, k),
    );

    await runTransaction(this.db, async (tx) => {
      const claim = await tx.get(claimRef);
      const barcodeClaims = await Promise.all(barcodeClaimRefs.map((r) => tx.get(r)));
      if (claim.exists()) throw new DuplicateSkuError();
      if (barcodeClaims.some((c) => c.exists())) throw new DuplicateBarcodeError();
      tx.set(productRef, productData);
      tx.set(claimRef, claimData);
      barcodeClaimRefs.forEach((r, i) => {
        tx.set(r, {
          barcode: barcodeKeys[i],
          productId,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      });
    });
    const created = await this.getById(productId);
    if (!created) throw new Error('Failed to load the created product');
    return created;
  }

  async update(id: string, input: ProductUpdateInput, actorId: string): Promise<void> {
    await updateDoc(
      doc(this.db, FirestoreCollections.products, id),
      this.updateData(input, actorId),
    );
  }

  private updateData(input: ProductUpdateInput, actorId: string) {
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
  async adjustStock(id: string, delta: number, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      quantity: increment(delta),
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async setStock(id: string, quantity: number, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      quantity,
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async deactivate(id: string, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      isActive: false,
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async reactivate(id: string, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      isActive: true,
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async recordPriceChange(
    productId: string,
    entry: Omit<PriceHistoryEntry, 'changedAt'>,
  ): Promise<void> {
    await addDoc(
      collection(this.db, FirestoreCollections.products, productId, Subcollections.priceHistory),
      {
        price: entry.price,
        cost: entry.cost,
        changedAt: serverTimestamp(),
        changedBy: entry.changedBy,
        reason: entry.reason,
      },
    );
  }
  async listPriceHistory(productId: string): Promise<PriceHistoryEntry[]> {
    const snap = await getDocs(
      query(
        collection(this.db, FirestoreCollections.products, productId, Subcollections.priceHistory),
        orderBy('changedAt', 'desc'),
        limit(50),
      ),
    );
    return snap.docs.map((d) => {
      const data = d.data();
      return {
        price: (data.price as number) ?? 0,
        cost: (data.cost as number) ?? 0,
        changedAt: toDate(data.changedAt) ?? new Date(0),
        changedBy: (data.changedBy as string) ?? '',
        reason: (data.reason as string | null) ?? null,
        note: (data.note as string | null) ?? null,
      };
    });
  }
}

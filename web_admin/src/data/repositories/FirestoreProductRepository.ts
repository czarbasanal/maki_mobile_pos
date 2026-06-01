// Read-side implementation of ProductRepository. Phase 2 needs watchAll (for
// the dashboard inventory-status counts). Write paths land in phase 7.

import {
  addDoc,
  collection,
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
import { normalizeSku, isValidSku } from '@/domain/products/sku';
import { DuplicateSkuError } from '@/data/errors';
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
    const snap = await getDocs(query(this.col(), where('barcode', '==', barcode)));
    return snap.empty ? null : snap.docs[0].data();
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

  async updateProductWithSku(
    id: string,
    input: ProductUpdateInput,
    oldSku: string,
    newSku: string,
    actorId: string,
    actorName: string | null,
  ): Promise<void> {
    // Variation children must be read OUTSIDE the transaction (Firestore
    // transactions can't run queries) — same as the previous writeBatch.
    const children = await getDocs(
      query(collection(this.db, FirestoreCollections.products), where('baseSku', '==', oldSku)),
    );
    const oldClaimRef = doc(
      this.db,
      FirestoreCollections.productSkus,
      normalizeSku(oldSku),
    );
    const newClaimRef = doc(
      this.db,
      FirestoreCollections.productSkus,
      normalizeSku(newSku),
    );
    // Move the parent's claim (delete old, set new), update the parent, and
    // re-point every child's baseSku — atomically, so the variation group never
    // observes a dangling parent link.
    await runTransaction(this.db, async (tx) => {
      const newClaim = await tx.get(newClaimRef);
      if (
        newClaim.exists() &&
        (newClaim.data() as { productId?: string }).productId !== id
      ) {
        throw new DuplicateSkuError();
      }
      // Product doc: reuse updateData so searchKeywords rebuild + whitelist apply.
      tx.update(
        doc(this.db, FirestoreCollections.products, id),
        this.updateData({ ...input, sku: newSku }, actorId),
      );
      for (const child of children.docs) {
        tx.update(child.ref, {
          baseSku: newSku,
          updatedBy: actorId,
          updatedByName: actorName,
          updatedAt: serverTimestamp(),
        });
      }
      // delete-then-set is safe even when old == new (case-only rename): same
      // ref → the set wins, re-keying the claim's sku field.
      tx.delete(oldClaimRef);
      tx.set(newClaimRef, {
        sku: newSku,
        productId: id,
        claimedBy: actorId,
        claimedAt: serverTimestamp(),
      });
    });
  }

  async barcodeExists(barcode: string): Promise<boolean> {
    return (await this.getByBarcode(barcode)) != null;
  }

  // Write methods land in phase 7.
  async create(input: ProductCreateInput, actorId: string): Promise<Product> {
    // The SKU becomes a product_skus claim doc-id (normalizeSku(sku)); reject
    // SKUs that can't form a valid doc-id ('/', empty) before the transaction
    // so it fails with a clear message rather than an opaque Firestore error.
    if (!isValidSku(normalizeSku(input.sku))) {
      throw new Error(
        `Invalid SKU "${input.sku}" — use letters, numbers, and hyphens only.`,
      );
    }
    const ref = doc(collection(this.db, FirestoreCollections.products));
    const claimRef = doc(
      this.db,
      FirestoreCollections.productSkus,
      normalizeSku(input.sku),
    );
    await runTransaction(this.db, async (tx) => {
      const claim = await tx.get(claimRef);
      if (claim.exists()) throw new DuplicateSkuError();
      tx.set(ref, this.createData(input, actorId));
      tx.set(claimRef, {
        sku: input.sku,
        productId: ref.id,
        claimedBy: actorId,
        claimedAt: serverTimestamp(),
      });
    });
    const created = await this.getById(ref.id);
    if (!created) throw new Error('Failed to load the created product');
    return created;
  }

  async update(id: string, input: ProductUpdateInput, actorId: string): Promise<void> {
    await updateDoc(
      doc(this.db, FirestoreCollections.products, id),
      this.updateData(input, actorId),
    );
  }

  private createData(input: ProductCreateInput, actorId: string) {
    const searchKeywords =
      input.searchKeywords ??
      generateSearchKeywords([input.sku, input.name, input.category]);
    return {
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
    };
  }

  private updateData(input: ProductUpdateInput, actorId: string) {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    const valueFields = [
      'sku', 'name', 'costCode', 'cost', 'price', 'quantity', 'reorderLevel',
      'unit', 'supplierId', 'supplierName', 'isActive', 'baseSku',
      'variationNumber', 'barcode', 'category', 'imageUrl', 'notes', 'updatedByName',
    ] as const;
    for (const key of valueFields) {
      if (input[key] !== undefined) data[key] = input[key];
    }
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

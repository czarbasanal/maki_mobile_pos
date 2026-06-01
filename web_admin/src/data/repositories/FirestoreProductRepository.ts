// Read-side implementation of ProductRepository. Phase 2 needs watchAll (for
// the dashboard inventory-status counts). Write paths land in phase 7.

import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
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

  async skuExists(sku: string): Promise<boolean> {
    return (await this.getBySku(sku)) != null;
  }

  async barcodeExists(barcode: string): Promise<boolean> {
    return (await this.getByBarcode(barcode)) != null;
  }

  // Write methods land in phase 7.
  async create(input: ProductCreateInput, actorId: string): Promise<Product> {
    const ref = await addDoc(
      collection(this.db, FirestoreCollections.products),
      this.createData(input, actorId),
    );
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
  async adjustStock(): Promise<void> {
    throw new Error('ProductRepository.adjustStock not implemented yet (phase 7)');
  }
  async setStock(): Promise<void> {
    throw new Error('ProductRepository.setStock not implemented yet (phase 7)');
  }
  async deactivate(): Promise<void> {
    throw new Error('ProductRepository.deactivate not implemented yet (phase 7)');
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

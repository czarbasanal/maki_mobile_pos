// Read-side implementation of ProductRepository. Phase 2 needs watchAll (for
// the dashboard inventory-status counts). Write paths land in phase 7.

import {
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  where,
  type Firestore,
} from 'firebase/firestore';
import type { ProductRepository } from '@/domain/repositories/ProductRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Product } from '@/domain/entities';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { productConverter } from '@/data/converters/productConverter';

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
  async create(): Promise<Product> {
    throw new Error('ProductRepository.create not implemented yet (phase 7)');
  }
  async update(): Promise<void> {
    throw new Error('ProductRepository.update not implemented yet (phase 7)');
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
  async recordPriceChange(): Promise<void> {
    throw new Error('ProductRepository.recordPriceChange not implemented yet (phase 7)');
  }
  async listPriceHistory(): Promise<never[]> {
    throw new Error('ProductRepository.listPriceHistory not implemented yet (phase 7)');
  }
}

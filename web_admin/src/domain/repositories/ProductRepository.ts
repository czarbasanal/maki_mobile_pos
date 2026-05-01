// Mirror of lib/domain/repositories/product_repository.dart.
// Implementations arrive in phase 7 (`/inventory`).

import type { Product } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface ProductCreateInput
  extends Omit<Product, 'id' | 'createdAt' | 'updatedAt' | 'searchKeywords'> {
  searchKeywords?: string[];
}

export interface ProductUpdateInput extends Partial<Omit<Product, 'id' | 'createdAt'>> {}

export interface PriceHistoryEntry {
  price: number;
  cost: number;
  changedAt: Date;
  changedBy: string;
  reason: string | null;
}

export interface ProductRepository {
  getById(id: string): Promise<Product | null>;
  getBySku(sku: string): Promise<Product | null>;
  getByBarcode(barcode: string): Promise<Product | null>;
  list(): Promise<Product[]>;
  watchAll(callback: (products: Product[]) => void): Unsubscribe;
  watchOne(id: string, callback: (product: Product | null) => void): Unsubscribe;
  search(query: string): Promise<Product[]>;
  listBySupplier(supplierId: string): Promise<Product[]>;
  listLowStock(): Promise<Product[]>;
  create(input: ProductCreateInput, actorId: string): Promise<Product>;
  update(id: string, input: ProductUpdateInput, actorId: string): Promise<void>;
  adjustStock(id: string, delta: number, actorId: string): Promise<void>;
  setStock(id: string, quantity: number, actorId: string): Promise<void>;
  deactivate(id: string, actorId: string): Promise<void>;
  recordPriceChange(productId: string, entry: Omit<PriceHistoryEntry, 'changedAt'>): Promise<void>;
  listPriceHistory(productId: string): Promise<PriceHistoryEntry[]>;
  skuExists(sku: string): Promise<boolean>;
  barcodeExists(barcode: string): Promise<boolean>;
}

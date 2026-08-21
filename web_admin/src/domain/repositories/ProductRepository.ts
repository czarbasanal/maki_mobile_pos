// Mirror of lib/domain/repositories/product_repository.dart.
// Implementations arrive in phase 7 (`/inventory`).

import type { Product } from '../entities';
import type { Unsubscribe } from './AuthRepository';
import type { PriceChangeEntry } from '@/domain/products/priceChangeReport';

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
  /** Free-text context; receiving entries carry the `RCV-…` id. Optional —
   *  web `recordPriceChange` doesn't write it, but mobile-written docs have it. */
  note?: string | null;
  /** The selling option this entry is about. Absent (or null) means "base
   *  price" — which is every entry recorded before this feature existed, so
   *  no backfill is required. */
  optionId?: string | null;
  /** Denormalized option label at the time of the change. */
  optionLabel?: string | null;
  /** Denormalized option piece count at the time of the change. */
  optionPieces?: number | null;
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
  /**
   * `autoSkuCategoryCode`: when set AND `input.sku` matches that code's
   * Code128 auto pattern (see domain/products/sku.ts `matchesAutoPattern`),
   * the create transaction peeks/claims the next free sequence in that
   * category's registry instead of trusting `input.sku` verbatim — mirrors
   * `ProductRepositoryImpl.createProduct`'s `autoSkuCategoryCode` path on
   * mobile. Omitted (or a non-matching sku) is the plain manual path,
   * byte-identical to before this param existed.
   */
  create(input: ProductCreateInput, actorId: string, autoSkuCategoryCode?: string): Promise<Product>;
  /**
   * `includeSellingOptions`: must stay false for non-admin writers.
   * sellingOptions sets prices and is admin-only in firestore.rules, so the
   * write payload only includes it when the caller has confirmed the actor
   * is an admin (see useProductMutations.ts). Defaults to false.
   */
  update(
    id: string,
    input: ProductUpdateInput,
    actorId: string,
    includeSellingOptions?: boolean,
  ): Promise<void>;
  adjustStock(id: string, delta: number, actorId: string, actorName: string | null): Promise<void>;
  setStock(id: string, quantity: number, actorId: string, actorName: string | null): Promise<void>;
  deactivate(id: string, actorId: string, actorName: string | null): Promise<void>;
  reactivate(id: string, actorId: string, actorName: string | null): Promise<void>;
  recordPriceChange(productId: string, entry: Omit<PriceHistoryEntry, 'changedAt'>): Promise<void>;
  listPriceHistory(productId: string): Promise<PriceHistoryEntry[]>;
  /** Cross-product price/cost changes in the range, newest-first (admin-only;
   *  needs the collection-group index on price_history.changedAt). */
  listPriceChangesInRange(start: Date, end: Date, limit?: number): Promise<PriceChangeEntry[]>;
  skuExists(sku: string, excludeId?: string): Promise<boolean>;
  countSkuVariations(baseSku: string): Promise<number>;
  /** The product holding this SKU's claim, matched on the NORMALIZED key so it
   *  agrees with the duplicate error the create transaction throws. */
  findBySkuClaim(sku: string): Promise<Product | null>;
  /** Next free `<baseSku>-N`, from the structured `variationNumber` field. */
  nextVariationNumber(baseSku: string): Promise<number>;
  /** Spawns a cost variation of `existing` — copies it, overrides cost/costCode
   *  and the allocated SKU, starts at zero stock with no barcodes. Retries when
   *  a concurrent writer claims the number first. */
  createVariation(
    existing: Product,
    opts: { cost: number; costCode: string; actorId: string; actorName: string | null },
  ): Promise<Product>;
  updateProductWithClaims(
    id: string,
    input: ProductUpdateInput,
    sku: { old: string; next: string; changed: boolean },
    barcode: { old: string[]; next: string[] },
    actorId: string,
    actorName: string | null,
    includeSellingOptions?: boolean,
  ): Promise<void>;
  barcodeExists(barcode: string, excludeProductId?: string): Promise<boolean>;
}

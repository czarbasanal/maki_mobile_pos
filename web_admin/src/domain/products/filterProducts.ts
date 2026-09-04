// Pure list-filter for the inventory page. Unit-tested in node env, so it uses
// RELATIVE imports (vitest doesn't resolve @/).
import { getStockStatus } from '../entities/Product';
import type { Product, StockStatus } from '../entities/Product';
import { matchesProductQuery } from './productSearch';

/** Tag-filter sentinel: products with no ACTIVE tag (spec: orphaned ids from
 *  deleted tags count as untagged — they never render as chips either). */
export const UNTAGGED = '__untagged__';

export interface ProductFilter {
  search: string; // '' disables search
  stock: StockStatus | 'all';
  category: string | 'all';
  /** Archived products are hidden unless asked for. 'all' shows both. */
  status: 'active' | 'inactive' | 'all';
  /** A product_tags id, UNTAGGED, or 'all'. Optional so existing callers are
   *  untouched — undefined disables the axis. */
  tag?: string | 'all';
  /** Active tag ids; consulted only for UNTAGGED. */
  activeTagIds?: readonly string[];
}

/** Filters by name/SKU substring (case-insensitive), stock status, category,
 *  active status, and tag. 'all' / '' disable that axis; axes are ANDed. */
export function filterProducts(products: Product[], f: ProductFilter): Product[] {
  const q = f.search.trim();
  return products.filter((p) => {
    // Tokenized, order/whitespace-insensitive, over name/sku/barcodes/category.
    if (q && !matchesProductQuery(p, q)) {
      return false;
    }
    if (f.stock !== 'all' && getStockStatus(p) !== f.stock) return false;
    if (f.category !== 'all' && (p.category ?? '') !== f.category) return false;
    if (f.status === 'active' && !p.isActive) return false;
    if (f.status === 'inactive' && p.isActive) return false;
    const tag = f.tag ?? 'all';
    if (tag !== 'all') {
      if (tag === UNTAGGED) {
        const active = new Set(f.activeTagIds ?? []);
        if (p.tagIds.some((id) => active.has(id))) return false;
      } else if (!p.tagIds.includes(tag)) {
        return false;
      }
    }
    return true;
  });
}

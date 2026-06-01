// Pure list-filter for the inventory page. Unit-tested in node env, so it uses
// RELATIVE imports (vitest doesn't resolve @/).
import { getStockStatus } from '../entities/Product';
import type { Product, StockStatus } from '../entities/Product';

export interface ProductFilter {
  search: string; // '' disables search
  stock: StockStatus | 'all';
  category: string | 'all';
}

/** Filters by name/SKU substring (case-insensitive), stock status, and
 *  category. 'all' / '' disable that axis; axes are ANDed. */
export function filterProducts(products: Product[], f: ProductFilter): Product[] {
  const q = f.search.trim().toLowerCase();
  return products.filter((p) => {
    if (q && !(p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q))) {
      return false;
    }
    if (f.stock !== 'all' && getStockStatus(p) !== f.stock) return false;
    if (f.category !== 'all' && (p.category ?? '') !== f.category) return false;
    return true;
  });
}

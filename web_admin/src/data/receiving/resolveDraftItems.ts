import type { Product, ReceivingItem } from '../../domain/entities';
import type { ReceivableItem } from '../../domain/receiving/receivableItem';

const COST_TOLERANCE = 0.01;

/** Re-derives ReceivableItems from a draft's persisted items against the
 *  CURRENT inventory (so match/mismatch reflects today's product cost). New
 *  items (pendingNewProduct) are resolved straight from the persisted spec.
 *  Existing items whose product no longer exists are dropped. */
export function resolveDraftItems(items: ReceivingItem[], products: Product[]): ReceivableItem[] {
  const byId = new Map(products.map((p) => [p.id, p]));
  const out: ReceivableItem[] = [];
  items.forEach((it, index) => {
    if (it.pendingNewProduct) {
      const np = it.pendingNewProduct;
      out.push({
        ref: index, kind: 'new', sku: it.sku, autoGenerateSku: np.autoGenerateSku,
        name: it.name, category: np.category, unit: it.unit, cost: it.unitCost,
        price: np.price, quantity: it.quantity, reorderLevel: np.reorderLevel,
      });
      return;
    }
    const product = it.productId ? byId.get(it.productId) : undefined;
    if (!product) return; // product gone — skip
    if (Math.abs(product.cost - it.unitCost) <= COST_TOLERANCE) {
      out.push({ ref: index, kind: 'match', product, quantity: it.quantity });
    } else {
      out.push({ ref: index, kind: 'mismatch', product, quantity: it.quantity, cost: it.unitCost });
    }
  });
  return out;
}

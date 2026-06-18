import type { ProductCreateInput } from '../../domain/repositories/ProductRepository';
import type { ReceivingItem } from '../../domain/entities';
import type { CostCode } from '../../domain/entities/CostCode';
import { encodeCostCode } from '../../domain/entities/CostCode';
import type { ReceivableItem } from '../../domain/receiving/receivableItem';
import { generateSku } from '../../domain/products/sku';
import { nextVariationNumber, variationSku } from '../../domain/receiving/variations';

export interface ReceiveContext {
  cipher: CostCode;
  actor: { id: string; name: string | null };
  supplier: { id: string; name: string } | null;
  /** SKUs already in inventory — variation numbers are allocated against these
   *  (plus in-plan allocations) so a single receiving never collides with itself. */
  knownSkus: string[];
}

export interface PlannedCreate {
  productId: string;
  input: ProductCreateInput;
  priceHistory: { price: number; cost: number; reason: string };
}

export interface ReceivePlan {
  creates: PlannedCreate[];
  /** productId -> qty to increment (matches only; new/variation get stock at create). */
  increments: Map<string, number>;
  items: ReceivingItem[];
  newProducts: number;
  variations: number;
  received: number; // line items
}

function productInput(
  p: {
    sku: string; name: string; cost: number; costCode: string; price: number; quantity: number;
    reorderLevel: number; unit: string; category: string | null; supplierId: string | null;
    supplierName: string | null; baseSku: string | null; variationNumber: number | null;
  },
  actor: ReceiveContext['actor'],
): ProductCreateInput {
  const actorName = actor.name?.trim() || null;
  return {
    sku: p.sku, name: p.name, costCode: p.costCode, cost: p.cost, price: p.price,
    quantity: p.quantity, reorderLevel: p.reorderLevel, unit: p.unit,
    supplierId: p.supplierId, supplierName: p.supplierName, isActive: true,
    createdBy: actor.id, updatedBy: actor.id, createdByName: actorName, updatedByName: actorName,
    baseSku: p.baseSku, variationNumber: p.variationNumber, barcode: null,
    category: p.category, imageUrl: null, notes: null,
    // searchKeywords intentionally omitted — buildProductWrites generates them.
  };
}

function item(over: Omit<ReceivingItem, 'id' | 'notes' | 'pendingNewProduct'>): ReceivingItem {
  return { ...over, id: crypto.randomUUID(), notes: null, pendingNewProduct: null };
}

/**
 * Pure: turns receivables into a plan of writes (products to create + their
 * price-history + the stock increments for matches + the resolved
 * ReceivingItems). Allocates variation SKUs from `knownSkus` (+ in-plan).
 * Performs NO Firestore I/O and NO claim checks — `executeReceivePlan` reads the
 * claims inside the transaction and aborts atomically on a real collision.
 * `makeId` supplies fresh product ids (a Firestore auto-id in prod).
 */
export function planReceive(
  receivables: ReceivableItem[],
  ctx: ReceiveContext,
  makeId: () => string,
): ReceivePlan {
  const creates: PlannedCreate[] = [];
  const increments = new Map<string, number>();
  const items: ReceivingItem[] = [];
  const knownSkus = [...ctx.knownSkus];
  let newProducts = 0;
  let variations = 0;

  for (const rec of receivables) {
    if (rec.kind === 'match') {
      const p = rec.product;
      increments.set(p.id, (increments.get(p.id) ?? 0) + rec.quantity);
      items.push(item({
        productId: p.id, sku: p.sku, name: p.name, quantity: rec.quantity,
        unit: p.unit, unitCost: p.cost, costCode: p.costCode,
        isNewVariation: false, newProductId: null,
      }));
    } else if (rec.kind === 'mismatch') {
      const p = rec.product;
      const base = p.baseSku ?? p.sku;
      const costCode = encodeCostCode(ctx.cipher, rec.cost);
      const n = nextVariationNumber(base, knownSkus);
      const sku = variationSku(base, n);
      knownSkus.push(sku);
      const productId = makeId();
      creates.push({
        productId,
        input: productInput({
          sku, name: p.name, cost: rec.cost, costCode, price: p.price,
          quantity: rec.quantity, reorderLevel: p.reorderLevel, unit: p.unit,
          category: p.category, supplierId: p.supplierId, supplierName: p.supplierName,
          baseSku: base, variationNumber: n,
        }, ctx.actor),
        priceHistory: { price: p.price, cost: rec.cost, reason: 'receiving' },
      });
      variations += 1;
      items.push(item({
        productId: p.id, sku, name: p.name, quantity: rec.quantity, unit: p.unit,
        unitCost: rec.cost, costCode, isNewVariation: true, newProductId: productId,
      }));
    } else {
      const sku = rec.autoGenerateSku ? generateSku(rec.name) : rec.sku;
      knownSkus.push(sku);
      const costCode = encodeCostCode(ctx.cipher, rec.cost);
      const productId = makeId();
      creates.push({
        productId,
        input: productInput({
          sku, name: rec.name, cost: rec.cost, costCode, price: rec.price,
          quantity: rec.quantity, reorderLevel: rec.reorderLevel, unit: rec.unit,
          category: rec.category, supplierId: ctx.supplier?.id ?? null,
          supplierName: ctx.supplier?.name ?? null, baseSku: null, variationNumber: null,
        }, ctx.actor),
        priceHistory: { price: rec.price, cost: rec.cost, reason: 'Initial price' },
      });
      newProducts += 1;
      items.push(item({
        productId, sku, name: rec.name, quantity: rec.quantity, unit: rec.unit,
        unitCost: rec.cost, costCode, isNewVariation: false, newProductId: null,
      }));
    }
  }

  return { creates, increments, items, newProducts, variations, received: items.length };
}

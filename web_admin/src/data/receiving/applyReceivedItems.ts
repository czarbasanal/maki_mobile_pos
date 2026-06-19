import type { Product, ReceivingItem } from '../../domain/entities';
import type { ProductCreateInput, ProductRepository } from '../../domain/repositories/ProductRepository';
import type { ReceivableItem } from '../../domain/receiving/receivableItem';
import type { CostCode } from '../../domain/entities/CostCode';
import { encodeCostCode } from '../../domain/entities/CostCode';
import { generateSku } from '../../domain/products/sku';
import { generateSearchKeywords } from '../../domain/products/searchKeywords';
import { nextVariationNumber, variationSku } from '../../domain/receiving/variations';
import { DuplicateSkuError } from '../errors';

export interface ReceiveContext {
  cipher: CostCode;
  actor: { id: string; name: string | null };
  supplier: { id: string; name: string } | null;
  knownSkus: string[];
}

export interface ReceiveOutcome {
  items: ReceivingItem[];
  increments: Map<string, number>;
  newProducts: number;
  variations: number;
  received: number;
  failed: { ref: string | number; message: string }[];
}

const MAX_VARIATION_ATTEMPTS = 5;

interface NewProductFields {
  sku: string; name: string; cost: number; costCode: string; price: number;
  quantity: number; reorderLevel: number; unit: string; category: string | null;
  supplierId: string | null; supplierName: string | null;
  baseSku: string | null; variationNumber: number | null;
}

function buildProductInput(p: NewProductFields, actor: ReceiveContext['actor']): ProductCreateInput {
  const actorName = actor.name?.trim() || null;
  return {
    sku: p.sku, name: p.name, costCode: p.costCode, cost: p.cost, price: p.price,
    quantity: p.quantity, reorderLevel: p.reorderLevel, unit: p.unit,
    supplierId: p.supplierId, supplierName: p.supplierName, isActive: true,
    createdBy: actor.id, updatedBy: actor.id, createdByName: actorName, updatedByName: actorName,
    searchKeywords: generateSearchKeywords([p.sku, p.name, p.category]),
    baseSku: p.baseSku, variationNumber: p.variationNumber, barcodes: [],
    category: p.category, imageUrl: null, notes: null,
  };
}

function buildItem(over: Omit<ReceivingItem, 'id' | 'notes'>): ReceivingItem {
  return { ...over, id: crypto.randomUUID(), notes: null };
}

export async function applyReceivedItems(
  receivables: ReceivableItem[],
  products: ProductRepository,
  ctx: ReceiveContext,
): Promise<ReceiveOutcome> {
  const items: ReceivingItem[] = [];
  const increments = new Map<string, number>();
  const knownSkus = [...ctx.knownSkus];
  const failed: ReceiveOutcome['failed'] = [];
  let newProducts = 0;
  let variations = 0;

  for (const rec of receivables) {
    try {
      if (rec.kind === 'match') {
        const p = rec.product;
        increments.set(p.id, (increments.get(p.id) ?? 0) + rec.quantity);
        items.push(buildItem({
          productId: p.id, sku: p.sku, name: p.name, quantity: rec.quantity,
          unit: p.unit, unitCost: p.cost, costCode: p.costCode,
          isNewVariation: false, newProductId: null,
        }));
      } else if (rec.kind === 'mismatch') {
        const p = rec.product;
        const base = p.baseSku ?? p.sku;
        const costCode = encodeCostCode(ctx.cipher, rec.cost);
        let n = nextVariationNumber(base, knownSkus);
        let created: Product | undefined;
        let sku = '';
        for (let attempt = 0; attempt < MAX_VARIATION_ATTEMPTS; attempt += 1) {
          sku = variationSku(base, n);
          try {
            created = await products.create(
              buildProductInput({
                sku, name: p.name, cost: rec.cost, costCode, price: p.price,
                quantity: rec.quantity, reorderLevel: p.reorderLevel, unit: p.unit,
                category: p.category, supplierId: p.supplierId, supplierName: p.supplierName,
                baseSku: base, variationNumber: n,
              }, ctx.actor),
              ctx.actor.id,
            );
            break;
          } catch (e) {
            if (e instanceof DuplicateSkuError) { n += 1; continue; }
            throw e;
          }
        }
        if (!created) throw new Error(`Could not allocate a unique variation SKU for "${base}"`);
        knownSkus.push(sku);
        await products.recordPriceChange(created.id, {
          price: p.price, cost: rec.cost, changedBy: ctx.actor.id, reason: 'receiving',
        });
        variations += 1;
        items.push(buildItem({
          productId: p.id, sku, name: p.name, quantity: rec.quantity, unit: p.unit,
          unitCost: rec.cost, costCode, isNewVariation: true, newProductId: created.id,
        }));
      } else {
        // new
        const sku = rec.autoGenerateSku ? generateSku(rec.name) : rec.sku;
        const costCode = encodeCostCode(ctx.cipher, rec.cost);
        const created = await products.create(
          buildProductInput({
            sku, name: rec.name, cost: rec.cost, costCode, price: rec.price,
            quantity: rec.quantity, reorderLevel: rec.reorderLevel, unit: rec.unit,
            category: rec.category, supplierId: ctx.supplier?.id ?? null,
            supplierName: ctx.supplier?.name ?? null, baseSku: null, variationNumber: null,
          }, ctx.actor),
          ctx.actor.id,
        );
        knownSkus.push(created.sku);
        await products.recordPriceChange(created.id, {
          price: rec.price, cost: rec.cost, changedBy: ctx.actor.id, reason: 'Initial price',
        });
        newProducts += 1;
        items.push(buildItem({
          productId: created.id, sku: created.sku, name: rec.name, quantity: rec.quantity,
          unit: rec.unit, unitCost: rec.cost, costCode, isNewVariation: false, newProductId: null,
        }));
      }
    } catch (e) {
      failed.push({ ref: rec.ref, message: (e as Error).message });
    }
  }

  const received = items.reduce((n, it) => n + it.quantity, 0);
  return { items, increments, newProducts, variations, received, failed };
}

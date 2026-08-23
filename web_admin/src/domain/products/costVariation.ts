// Cost-variation rules shared by the New Product form. When a typed SKU
// collides with an existing product at a DIFFERENT cost, the save spawns
// `<base>-N` rather than being rejected as a duplicate.
//
// Deliberately mirrors mobile's ProductRepositoryImpl.createVariation
// (lib/data/repositories/product_repository_impl.dart): the variation copies
// the existing product and overrides only cost/costCode/SKU, starting at zero
// stock with no barcodes. Keeping the two surfaces identical means a variation
// spawned from the web form is indistinguishable from one spawned by
// receiving. Pure -> relative imports.
import type { Product } from '../entities/Product';
import type { ProductCreateInput } from '../repositories/ProductRepository';

/** Same tolerance receiving classifies rows with (see
 *  domain/receiving/classifyReceivingRows.ts) — two costs within a centavo are
 *  the same cost, so a rounding wobble never spawns a phantom variation. */
const COST_TOLERANCE = 0.01;

/** Whether an entered cost is far enough from the existing product's cost to
 *  warrant a variation rather than a plain duplicate-SKU rejection. */
export function costsDiffer(a: number, b: number): boolean {
  return Math.abs(a - b) > COST_TOLERANCE;
}

/**
 * Next free variation number given the numbers already in use under a base.
 *
 * Takes the MAX rather than the count: deleting `-2` from a base holding
 * `-1 -2 -3` would make a count-based allocator return 3 and collide with the
 * live `-3`. Mirrors mobile's getNextVariationNumber, which reads the same
 * structured field instead of parsing SKU strings (SKUs like `rs8-001` carry
 * numeric segments that aren't variation suffixes).
 */
export function nextVariationNumberFrom(
  numbers: readonly (number | null | undefined)[],
): number {
  let max = 0;
  for (const n of numbers) {
    if (typeof n === 'number' && n > max) max = n;
  }
  return max + 1;
}

export interface VariationOptions {
  cost: number;
  costCode: string;
  variationNumber: number;
  actorId: string;
  actorName: string | null;
}

/**
 * Builds the create-input for a cost variation of `existing`.
 *
 * Everything descriptive is inherited so the variation reads as the same item
 * on the shelf; only cost, cost code and the allocated SKU differ. Stock
 * starts at zero because the variation is a container for units that haven't
 * been received yet, and it claims no barcodes because the manufacturer code
 * belongs to the base item — two products can't claim one barcode.
 */
export function buildVariationInput(
  existing: Product,
  opts: VariationOptions,
): ProductCreateInput {
  const base = existing.baseSku ?? existing.sku;
  return {
    sku: `${base}-${opts.variationNumber}`,
    baseSku: base,
    variationNumber: opts.variationNumber,
    cost: opts.cost,
    costCode: opts.costCode,
    quantity: 0,
    barcodes: [],
    name: existing.name,
    price: existing.price,
    reorderLevel: existing.reorderLevel,
    unit: existing.unit,
    supplierId: existing.supplierId,
    supplierName: existing.supplierName,
    // NOT inherited. Varying an archived product would otherwise create one the
    // inventory list hides by default — the user sees nothing, concludes the
    // save failed, and the SKU is claimed either way. A product being created
    // right now is a live one.
    isActive: true,
    sellingOptions: existing.sellingOptions,
    category: existing.category,
    // DELIBERATELY shared, not duplicated. Both docs end up pointing at
    // `products/{baseId}/main.jpg`, so removing the BASE product's image
    // deletes the file out from under every variation and their photos break.
    // That is a known, accepted trade: a cost variation is the same physical
    // part, and carrying the photo across is worth more day to day than the
    // rare broken image. Copying the file instead would need a CORS config on
    // the Storage bucket to fetch it client-side.
    //
    // Note this differs from a receiving-spawned variation on web, which gets
    // `imageUrl: null` (planReceive.ts) — mobile's createVariation carries the
    // URL over, and matching mobile is the intent here.
    imageUrl: existing.imageUrl,
    notes: existing.notes,
    createdBy: opts.actorId,
    updatedBy: null,
    createdByName: opts.actorName,
    updatedByName: null,
  };
}

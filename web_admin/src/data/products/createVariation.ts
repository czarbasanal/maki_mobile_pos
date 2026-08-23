// Allocation + retry for cost variations, split out of the repository so the
// race handling can be tested against a real fake rather than a Firestore mock.
import type { Product } from '@/domain/entities/Product';
import { buildVariationInput, type VariationOptions } from '@/domain/products/costVariation';
import type { ProductCreateInput } from '@/domain/repositories/ProductRepository';
import { DuplicateSkuError } from '../errors';

export interface VariationDeps {
  /** Next free variation number under the base, read fresh on every attempt. */
  nextNumber: () => Promise<number>;
  create: (input: ProductCreateInput) => Promise<Product>;
}

/**
 * Creates a cost variation of `existing`, retrying when a concurrent writer
 * claims the number first.
 *
 * The number is recomputed inside the loop, not once up front: a losing writer
 * only advances after the winner's product commits, so re-reading is what makes
 * the second attempt pick a free slot. Mirrors mobile's createVariation, down
 * to the five-attempt cap.
 */
export async function allocateVariation(
  existing: Product,
  opts: Omit<VariationOptions, 'variationNumber'>,
  deps: VariationDeps,
  maxAttempts = 5,
): Promise<Product> {
  const base = existing.baseSku ?? existing.sku;
  // Floor rises past every number that turned out to be taken, guaranteeing a
  // strictly increasing candidate. Without it the loop can stall: nextNumber()
  // reads the structured `variationNumber` field while `create` collides on the
  // SKU *claim*, so a `<base>-1` carrying no variation number (hand-typed, or
  // from the bulk import) would be proposed on every attempt and that base
  // could never be varied at all.
  let floor = 0;

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const variationNumber = Math.max(await deps.nextNumber(), floor + 1);
    try {
      return await deps.create(buildVariationInput(existing, { ...opts, variationNumber }));
    } catch (e) {
      // Only a lost SKU race is retryable — anything else (offline, rules
      // denial, a duplicate BARCODE) must surface as itself.
      if (!(e instanceof DuplicateSkuError)) throw e;
      floor = variationNumber;
    }
  }

  throw new Error(
    `Could not allocate a unique variation SKU for "${base}" after ${maxAttempts} attempts`,
  );
}

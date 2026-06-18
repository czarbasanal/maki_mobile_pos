import {
  collection,
  doc,
  increment,
  serverTimestamp,
  type Firestore,
  type Transaction,
} from 'firebase/firestore';
import { FirestoreCollections, Subcollections } from '@/infrastructure/firebase/collections';
import { buildProductWrites } from '@/data/products/productWrites';
import { DuplicateSkuError } from '@/data/errors';
import type { ReceivePlan } from './planReceive';

/**
 * Applies a ReceivePlan inside an open Firestore transaction: creates each
 * planned product (+ its SKU claim + an initial price-history entry) and
 * increments stock for matched products. Reads (claim-existence checks) run
 * before any write, per Firestore's transaction rule. A claim that already
 * exists throws DuplicateSkuError, aborting the whole transaction atomically —
 * so a partially-applied receiving can never be committed. The caller writes
 * the receiving doc itself (as the final write in the same transaction).
 */
export async function executeReceivePlan(
  tx: Transaction,
  db: Firestore,
  plan: ReceivePlan,
  actor: { id: string; name: string | null },
): Promise<void> {
  const built = plan.creates.map((c) => ({
    create: c,
    writes: buildProductWrites(db, c.input, actor.id, c.productId),
  }));

  // --- reads: all claim checks before any write ---
  for (const { writes } of built) {
    const claim = await tx.get(writes.claimRef);
    if (claim.exists()) throw new DuplicateSkuError();
  }

  // --- writes ---
  for (const { create, writes } of built) {
    tx.set(writes.productRef, writes.productData);
    tx.set(writes.claimRef, writes.claimData);
    tx.set(doc(collection(writes.productRef, Subcollections.priceHistory)), {
      price: create.priceHistory.price,
      cost: create.priceHistory.cost,
      changedAt: serverTimestamp(),
      changedBy: actor.id,
      reason: create.priceHistory.reason,
    });
  }
  for (const [productId, delta] of plan.increments) {
    tx.update(doc(db, FirestoreCollections.products, productId), {
      quantity: increment(delta),
      updatedBy: actor.id,
      updatedByName: actor.name,
      updatedAt: serverTimestamp(),
    });
  }
}

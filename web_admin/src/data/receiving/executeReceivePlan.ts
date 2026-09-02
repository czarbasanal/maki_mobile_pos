import {
  collection,
  doc,
  increment,
  serverTimestamp,
  type Firestore,
  type Transaction,
} from 'firebase/firestore';
import { FirestoreCollections, Subcollections } from '@/infrastructure/firebase/collections';
import { buildProductWrites, withAllocatedSku } from '@/data/products/productWrites';
import { DuplicateBarcodeError, DuplicateSkuError } from '@/data/errors';
import { composeAutoSku, isClaimableBarcode, normalizeSku, sequenceOf } from '@/domain/products/sku';
import { diffBarcodeClaims } from '@/domain/products/barcodes';
import type { ReceivePlan } from './planReceive';

/** Cap on claim-read scan attempts per auto-SKU create — mirrors
 *  FirestoreProductRepository.autoSkuScanCap. */
const AUTO_SKU_SCAN_CAP = 25;

/**
 * Applies a ReceivePlan inside an open Firestore transaction: creates each
 * planned product (+ its SKU claim, barcode claims, and an initial
 * price-history entry) and increments stock for matched products. Reads run
 * before any write, per Firestore's transaction rule.
 *
 * SKU handling mirrors FirestoreProductRepository.create — receiving writes
 * products with its own transaction body, so the create() path's guarantees
 * must be re-established here:
 * - A create carrying `autoSkuCategoryCode` treats `input.sku` as a peeked
 *   PREVIEW: the scan walks forward from max(preview, registry.nextSequence)
 *   until a free claim is found, then bumps the registry. A preview gone stale
 *   while the entry form sat open therefore shifts to the next code instead of
 *   failing the whole receiving.
 * - A literal SKU (manual, variation, legacy name-generated) that collides
 *   throws DuplicateSkuError, aborting the whole transaction atomically — a
 *   partially-applied receiving can never be committed.
 * - Barcodes are CLAIMED, not just written onto the product doc — without the
 *   claim docs the product_barcodes uniqueness guard would be bypassed.
 *
 * MUTATES `plan.items`: an auto row's item carries the peeked preview, so the
 * allocated SKU is stamped back onto it here. Callers persisting `plan.items`
 * must do so AFTER this returns.
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
    finalSku: c.input.sku,
    finalClaimRef: null as ReturnType<typeof doc> | null,
    registryRef: null as ReturnType<typeof doc> | null,
    registryNext: 0,
  }));

  // --- reads: all claim checks (and auto-SKU scans) before any write ---
  const claimedThisPlan = new Set<string>();
  for (const b of built) {
    const code = b.create.autoSkuCategoryCode;
    if (code != null) {
      const registryRef = doc(db, FirestoreCollections.categoryCodes, code);
      const registrySnap = await tx.get(registryRef);
      if (!registrySnap.exists()) throw new Error(`Unknown category code "${code}"`);
      const registryNext = (registrySnap.data()?.nextSequence as number | undefined) ?? 1;
      let candidate = Math.max(sequenceOf(b.create.input.sku), registryNext);

      let attempts = 0;
      for (;;) {
        attempts += 1;
        if (attempts > AUTO_SKU_SCAN_CAP) throw new Error('sku-scan-exhausted');
        const sku = composeAutoSku(code, candidate);
        const claimRef = doc(db, FirestoreCollections.productSkus, normalizeSku(sku));
        // Two auto rows in ONE receiving scan the same registry — the earlier
        // row's pick isn't visible via tx.get (its write lands later), so an
        // in-plan set keeps them off each other's sequence.
        if (!claimedThisPlan.has(claimRef.path)) {
          const snap = await tx.get(claimRef);
          if (!snap.exists()) {
            b.finalSku = sku;
            b.finalClaimRef = claimRef;
            b.registryRef = registryRef;
            b.registryNext = candidate + 1;
            claimedThisPlan.add(claimRef.path);
            break;
          }
        }
        candidate += 1;
      }
    } else {
      const claim = await tx.get(b.writes.claimRef);
      if (claim.exists() || claimedThisPlan.has(b.writes.claimRef.path)) {
        throw new DuplicateSkuError();
      }
      claimedThisPlan.add(b.writes.claimRef.path);
    }
  }

  // Barcode claims — validated and read-checked before any write, so one taken
  // barcode aborts the receiving before anything is created.
  const barcodeRefs = new Map<string, { ref: ReturnType<typeof doc>; productId: string; code: string }[]>();
  for (const b of built) {
    const refs: { ref: ReturnType<typeof doc>; productId: string; code: string }[] = [];
    // Same normalization as FirestoreProductRepository.create — the claim key
    // must match what a later barcode lookup normalizes to.
    for (const code of diffBarcodeClaims([], b.create.input.barcodes).added) {
      if (!isClaimableBarcode(code)) {
        throw new Error(`Invalid barcode "${code}" — it can't contain "/" or be "." or "..".`);
      }
      const ref = doc(db, FirestoreCollections.productBarcodes, code);
      const snap = await tx.get(ref);
      if (snap.exists()) throw new DuplicateBarcodeError();
      refs.push({ ref, productId: b.create.productId, code });
    }
    barcodeRefs.set(b.create.productId, refs);
  }

  // The receiving doc records a sku per line, and for an auto row that sku is
  // still the peeked preview — stale the moment the scan above moved past it,
  // and identical across two rows that peeked the same sequence. Re-stamp the
  // items with what was actually allocated so the history names the real
  // product. Keyed on the created product's id (a variation line carries it as
  // newProductId, with productId pointing at the product it varies).
  const allocatedByProductId = new Map(built.map((b) => [b.create.productId, b.finalSku]));
  for (const it of plan.items) {
    const allocated = allocatedByProductId.get(it.newProductId ?? it.productId ?? '');
    if (allocated !== undefined) it.sku = allocated;
  }

  // --- writes ---
  for (const b of built) {
    const { create, writes } = b;
    tx.set(writes.productRef, withAllocatedSku(writes.productData, create.input, b.finalSku));
    if (b.finalClaimRef != null) {
      tx.set(b.finalClaimRef, {
        sku: b.finalSku,
        productId: create.productId,
        claimedBy: actor.id,
        claimedAt: serverTimestamp(),
      });
      // Targeted write of only nextSequence (rules enforce hasOnly).
      tx.update(b.registryRef!, { nextSequence: b.registryNext });
    } else {
      tx.set(writes.claimRef, writes.claimData);
    }
    for (const { ref, productId, code } of barcodeRefs.get(create.productId) ?? []) {
      tx.set(ref, {
        barcode: code,
        productId,
        claimedBy: actor.id,
        claimedAt: serverTimestamp(),
      });
    }
    tx.set(doc(collection(writes.productRef, Subcollections.priceHistory)), {
      price: create.priceHistory.price,
      cost: create.priceHistory.cost,
      changedAt: serverTimestamp(),
      changedBy: actor.id,
      reason: create.priceHistory.reason,
    });
  }
  for (const [productId, delta] of plan.increments) {
    // A matched product with no supplier takes this receiving's
    // (fill-when-empty) — folded into the same update as its stock increment.
    const fill = plan.supplierFills.get(productId);
    tx.update(doc(db, FirestoreCollections.products, productId), {
      quantity: increment(delta),
      ...(fill ? { supplierId: fill.supplierId, supplierName: fill.supplierName } : {}),
      updatedBy: actor.id,
      updatedByName: actor.name,
      updatedAt: serverTimestamp(),
    });
  }
}

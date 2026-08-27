// Read-side implementation of ProductRepository. Phase 2 needs watchAll (for
// the dashboard inventory-status counts). Write paths land in phase 7.

import {
  addDoc,
  collection,
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  Timestamp,
  updateDoc,
  where,
  type Firestore,
} from 'firebase/firestore';
import type { ProductRepository } from '@/domain/repositories/ProductRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Product } from '@/domain/entities';
import { FirestoreCollections, Subcollections } from '@/infrastructure/firebase/collections';
import { productConverter } from '@/data/converters/productConverter';
import { toDate } from '@/data/converters/timestamps';
import {
  normalizeSku,
  normalizeBarcode,
  isClaimableBarcode,
  matchesAutoPattern,
  sequenceOf,
  composeAutoSku,
  normalizeSkuQuery,
} from '@/domain/products/sku';
import { diffBarcodeClaims } from '@/domain/products/barcodes';
import { nextVariationNumberFrom } from '@/domain/products/costVariation';
import { allocateVariation } from '@/data/products/createVariation';
import {
  buildProductUpdate,
  buildProductWrites,
  newProductId,
  withAllocatedSku,
} from '@/data/products/productWrites';
import { sellingOptionHistoryEvents } from '@/domain/products/sellingOptions';
import { DuplicateSkuError, DuplicateBarcodeError } from '@/data/errors';
import type { PriceChangeEntry } from '@/domain/products/priceChangeReport';
import type {
  PriceHistoryEntry,
  ProductCreateInput,
  ProductUpdateInput,
} from '@/domain/repositories/ProductRepository';

export class FirestoreProductRepository implements ProductRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.products).withConverter(productConverter);
  }

  async getById(id: string): Promise<Product | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.products, id).withConverter(productConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  async getBySku(sku: string): Promise<Product | null> {
    const snap = await getDocs(query(this.col(), where('sku', '==', sku)));
    return snap.empty ? null : snap.docs[0].data();
  }

  async getByBarcode(barcode: string): Promise<Product | null> {
    const code = normalizeBarcode(barcode);
    const byArray = await getDocs(query(this.col(), where('barcodes', 'array-contains', code)));
    if (!byArray.empty) return byArray.docs[0].data();
    // Legacy fallback: match the singular field on the raw argument (old docs
    // stored it un-normalized), preserving the old exact-match behavior.
    const byLegacy = await getDocs(query(this.col(), where('barcode', '==', barcode)));
    return byLegacy.empty ? null : byLegacy.docs[0].data();
  }

  async list(): Promise<Product[]> {
    const snap = await getDocs(query(this.col(), orderBy('name')));
    return snap.docs.map((d) => d.data());
  }

  watchAll(callback: (products: Product[]) => void): Unsubscribe {
    return onSnapshot(query(this.col(), orderBy('name')), (snap) => {
      callback(snap.docs.map((d) => d.data()));
    });
  }

  watchOne(id: string, callback: (product: Product | null) => void): Unsubscribe {
    return onSnapshot(
      doc(this.db, FirestoreCollections.products, id).withConverter(productConverter),
      (snap) => callback(snap.exists() ? snap.data() : null),
    );
  }

  async search(queryText: string): Promise<Product[]> {
    if (!queryText.trim()) return this.list();
    // SKUs are shown as 0007-0153, so that is what gets typed; searchKeywords
    // holds the stored 00070153.
    const term = normalizeSkuQuery(queryText.trim().toLowerCase());
    const snap = await getDocs(
      query(this.col(), where('searchKeywords', 'array-contains', term)),
    );
    return snap.docs.map((d) => d.data());
  }

  async listBySupplier(supplierId: string): Promise<Product[]> {
    const snap = await getDocs(query(this.col(), where('supplierId', '==', supplierId)));
    return snap.docs.map((d) => d.data());
  }

  async listLowStock(): Promise<Product[]> {
    // Firestore can't compare two fields directly; fetch active products and
    // filter client-side. Cheap for stock counts, fine for the dashboard.
    const snap = await getDocs(query(this.col(), where('isActive', '==', true)));
    return snap.docs.map((d) => d.data()).filter((p) => p.quantity <= p.reorderLevel);
  }

  async skuExists(sku: string, excludeId?: string): Promise<boolean> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku)),
    );
    if (!snap.exists()) return false;
    if (excludeId === undefined) return true;
    return (snap.data() as { productId?: string }).productId !== excludeId;
  }

  /** Every product filed under `baseSku`. Shared so countSkuVariations and
   *  nextVariationNumber can't drift apart on what "a variation" means. */
  private variationsOf(baseSku: string) {
    return query(this.col(), where('baseSku', '==', baseSku));
  }

  async countSkuVariations(baseSku: string): Promise<number> {
    const snap = await getDocs(this.variationsOf(baseSku));
    return snap.size;
  }

  /**
   * The product a SKU's claim points at, resolved through the NORMALIZED claim
   * key rather than the sku field.
   *
   * `getBySku` matches verbatim, so it would find nothing for `abc123` when the
   * product is stored as `ABC123` — yet the create transaction collides on the
   * normalized key and rejects that save as a duplicate. Only this lookup
   * agrees with the error the caller is reacting to.
   */
  async findBySkuClaim(sku: string): Promise<Product | null> {
    const claimSnap = await getDoc(
      doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku)),
    );
    if (!claimSnap.exists()) return null;
    const productId = (claimSnap.data() as { productId?: string } | undefined)?.productId;
    // A claim outliving its product would otherwise surface as a crash on the
    // form; treat the dangling case as "nothing to vary".
    if (!productId) return null;
    return this.getById(productId);
  }

  /** Next free `<baseSku>-N`. Reads the structured `variationNumber` field —
   *  see nextVariationNumberFrom for why this maxes rather than counts. */
  async nextVariationNumber(baseSku: string): Promise<number> {
    const snap = await getDocs(this.variationsOf(baseSku));
    return nextVariationNumberFrom(snap.docs.map((d) => d.data().variationNumber));
  }

  async createVariation(
    existing: Product,
    opts: { cost: number; costCode: string; actorId: string; actorName: string | null },
  ): Promise<Product> {
    return allocateVariation(existing, opts, {
      nextNumber: () => this.nextVariationNumber(existing.baseSku ?? existing.sku),
      create: (input) => this.create(input, opts.actorId),
    });
  }

  async updateProductWithClaims(
    id: string,
    input: ProductUpdateInput,
    sku: { old: string; next: string; changed: boolean },
    barcode: { old: string[]; next: string[] },
    actorId: string,
    actorName: string | null,
    includeSellingOptions = false,
  ): Promise<void> {
    // Read the prior sellingOptions (if this save might touch them) BEFORE
    // the transaction — mirrors mobile's updateProduct, which reads `prior`
    // ahead of its own write. Only reads when includeSellingOptions AND the
    // caller actually supplied a value, so a plain SKU/barcode edit (the
    // common case) costs nothing extra.
    const priorForHistory = await this.readPriorForSellingOptionHistory(id, input, includeSellingOptions);

    // Variation children (baseSku == old) must be read OUTSIDE the transaction
    // (Firestore transactions can't run queries) — only needed on a SKU rename.
    const children = sku.changed
      ? await getDocs(
          query(
            collection(this.db, FirestoreCollections.products),
            where('baseSku', '==', sku.old),
          ),
        )
      : null;

    const { added, removed } = diffBarcodeClaims(barcode.old, barcode.next);
    for (const key of added) {
      if (!isClaimableBarcode(key)) {
        throw new Error(`Invalid barcode "${key}" — it can't contain "/" or be "." or "..".`);
      }
    }
    const newSkuClaimRef = doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku.next));
    const addedRefs = added.map((k) => doc(this.db, FirestoreCollections.productBarcodes, k));
    const removedRefs = removed.map((k) => doc(this.db, FirestoreCollections.productBarcodes, k));

    // Move the SKU claim and/or diff the barcode claims, update the parent, and
    // re-point every child's baseSku — atomically, so the group never observes
    // a dangling link.
    await runTransaction(this.db, async (tx) => {
      // Reads first (Firestore transactions require reads-before-writes).
      const newSkuClaim = sku.changed ? await tx.get(newSkuClaimRef) : null;
      const addedClaims = await Promise.all(addedRefs.map((r) => tx.get(r)));
      if (
        sku.changed &&
        newSkuClaim!.exists() &&
        (newSkuClaim!.data() as { productId?: string }).productId !== id
      ) {
        throw new DuplicateSkuError();
      }
      if (
        addedClaims.some(
          (c) => c.exists() && (c.data() as { productId?: string }).productId !== id,
        )
      ) {
        throw new DuplicateBarcodeError();
      }
      // Product doc: reuse buildProductUpdate so searchKeywords rebuild +
      // the value-field whitelist apply. input already carries the new sku +
      // barcodes from the form patch.
      tx.update(
        doc(this.db, FirestoreCollections.products, id),
        buildProductUpdate(input, actorId, includeSellingOptions),
      );
      if (sku.changed) {
        for (const child of children!.docs) {
          tx.update(child.ref, {
            baseSku: sku.next,
            updatedBy: actorId,
            updatedByName: actorName,
            updatedAt: serverTimestamp(),
          });
        }
        // delete-then-set is safe even when old == next (case-only rename):
        // same ref → the set wins, re-keying the claim's sku field.
        tx.delete(doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku.old)));
        tx.set(newSkuClaimRef, {
          sku: sku.next,
          productId: id,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      }
      removedRefs.forEach((r) => tx.delete(r));
      addedRefs.forEach((r, i) => {
        tx.set(r, {
          barcode: added[i],
          productId: id,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      });
    });

    if (priorForHistory) {
      await this.recordSellingOptionHistory(id, priorForHistory, input, actorId);
    }
  }

  async barcodeExists(barcode: string, excludeProductId?: string): Promise<boolean> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.productBarcodes, normalizeBarcode(barcode)),
    );
    if (!snap.exists()) return false;
    if (excludeProductId === undefined) return true;
    return (snap.data() as { productId?: string }).productId !== excludeProductId;
  }

  // Write methods land in phase 7.
  async create(
    input: ProductCreateInput,
    actorId: string,
    autoSkuCategoryCode?: string,
  ): Promise<Product> {
    const productId = newProductId(this.db);
    const { productRef, productData, claimRef, claimData } = buildProductWrites(
      this.db,
      input,
      actorId,
      productId,
    );
    // Unique, normalized, non-empty barcode keys (reuse the diff helper: every
    // code is "added" vs an empty old set).
    const barcodeKeys = diffBarcodeClaims([], input.barcodes).added;
    for (const key of barcodeKeys) {
      if (!isClaimableBarcode(key)) {
        throw new Error(`Invalid barcode "${key}" — it can't contain "/" or be "." or "..".`);
      }
    }
    const barcodeClaimRefs = barcodeKeys.map((k) =>
      doc(this.db, FirestoreCollections.productBarcodes, k),
    );

    // Auto-SKU only kicks in when a category code was supplied AND the
    // caller's sku actually matches that code's auto pattern — anything else
    // (no code, or a manual-override sku) is the plain manual path below,
    // byte-identical to before this param existed.
    const autoMode =
      autoSkuCategoryCode !== undefined && matchesAutoPattern(input.sku, autoSkuCategoryCode);
    const registryRef = autoMode
      ? doc(this.db, FirestoreCollections.categoryCodes, autoSkuCategoryCode)
      : null;

    await runTransaction(this.db, async (tx) => {
      if (autoMode) {
        const registrySnap = await tx.get(registryRef!);
        if (!registrySnap.exists()) {
          throw new Error(`Unknown category code "${autoSkuCategoryCode}"`);
        }
        const registryNext = (registrySnap.data()?.nextSequence as number | undefined) ?? 1;
        let candidate = Math.max(sequenceOf(input.sku), registryNext);

        // Reads-before-writes: scan forward from the peeked candidate,
        // re-reading the claim doc each time, until a free sequence is
        // found (closes the peek-then-claim TOCTOU) or the scan cap trips.
        let finalSku = input.sku;
        let finalClaimRef = claimRef;
        let attempts = 0;
        while (true) {
          attempts += 1;
          if (attempts > FirestoreProductRepository.autoSkuScanCap) {
            throw new Error('sku-scan-exhausted');
          }
          // Must run before composeAutoSku (which throws its own generic
          // range error): an out-of-range candidate needs the specific
          // category-full error, not composeAutoSku's message.
          if (candidate > 9999) {
            throw new Error('Category is full — split it into two categories.');
          }
          finalSku = composeAutoSku(autoSkuCategoryCode!, candidate);
          finalClaimRef = doc(this.db, FirestoreCollections.productSkus, normalizeSku(finalSku));
          const candidateClaim = await tx.get(finalClaimRef);
          if (!candidateClaim.exists()) break;
          candidate += 1;
        }

        const barcodeClaims = await Promise.all(barcodeClaimRefs.map((r) => tx.get(r)));
        if (barcodeClaims.some((c) => c.exists())) throw new DuplicateBarcodeError();

        tx.set(productRef, withAllocatedSku(productData, input, finalSku));
        tx.set(finalClaimRef, {
          sku: finalSku,
          productId,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
        barcodeClaimRefs.forEach((r, i) => {
          tx.set(r, {
            barcode: barcodeKeys[i],
            productId,
            claimedBy: actorId,
            claimedAt: serverTimestamp(),
          });
        });
        // Targeted write of only nextSequence — leaves categoryId/
        // nameSnapshot/assignedAt untouched (rules enforce hasOnly(['nextSequence'])).
        tx.update(registryRef!, { nextSequence: candidate + 1 });
      } else {
        const claim = await tx.get(claimRef);
        const barcodeClaims = await Promise.all(barcodeClaimRefs.map((r) => tx.get(r)));
        if (claim.exists()) throw new DuplicateSkuError();
        if (barcodeClaims.some((c) => c.exists())) throw new DuplicateBarcodeError();
        tx.set(productRef, productData);
        tx.set(claimRef, claimData);
        barcodeClaimRefs.forEach((r, i) => {
          tx.set(r, {
            barcode: barcodeKeys[i],
            productId,
            claimedBy: actorId,
            claimedAt: serverTimestamp(),
          });
        });
      }
    });
    const created = await this.getById(productId);
    if (!created) throw new Error('Failed to load the created product');
    return created;
  }

  /** Cap on claim-read scan attempts inside the auto-SKU candidate loop. */
  private static readonly autoSkuScanCap = 25;

  async update(
    id: string,
    input: ProductUpdateInput,
    actorId: string,
    includeSellingOptions = false,
  ): Promise<void> {
    const priorForHistory = await this.readPriorForSellingOptionHistory(id, input, includeSellingOptions);

    await updateDoc(
      doc(this.db, FirestoreCollections.products, id),
      buildProductUpdate(input, actorId, includeSellingOptions),
    );

    if (priorForHistory) {
      await this.recordSellingOptionHistory(id, priorForHistory, input, actorId);
    }
  }

  /**
   * Reads the product's CURRENT (pre-write) sellingOptions + cost, but only
   * when this save could actually change sellingOptions — i.e. the caller is
   * on the admin-gated tier (`includeSellingOptions`) AND the patch supplies
   * the field. A plain edit that never touches sellingOptions (the common
   * case, and the only case for staff/cashier) skips this read entirely, so
   * this feature adds zero Firestore reads to those saves.
   */
  private async readPriorForSellingOptionHistory(
    id: string,
    input: ProductUpdateInput,
    includeSellingOptions: boolean,
  ): Promise<{ sellingOptions: Product['sellingOptions']; cost: number } | null> {
    if (!includeSellingOptions || input.sellingOptions === undefined) return null;
    const prior = await this.getById(id);
    if (!prior) return null;
    return { sellingOptions: prior.sellingOptions, cost: prior.cost };
  }

  /**
   * Diffs the prior sellingOptions against the patch and writes one
   * price_history doc per event (best-effort — mirrors the base price_history
   * write's failure posture: never fails the caller's save). Unit cost for
   * the option's SET cost is the NEW cost when this same edit also changes
   * it, else the prior (unchanged) cost.
   */
  private async recordSellingOptionHistory(
    productId: string,
    prior: { sellingOptions: Product['sellingOptions']; cost: number },
    input: ProductUpdateInput,
    changedBy: string,
  ): Promise<void> {
    const unitCost = input.cost ?? prior.cost;
    const events = sellingOptionHistoryEvents(prior.sellingOptions, input.sellingOptions!, unitCost);
    for (const event of events) {
      try {
        await this.recordPriceChange(productId, {
          price: event.price,
          cost: event.cost,
          changedBy,
          reason: event.reason,
          optionId: event.optionId,
          optionLabel: event.optionLabel,
          optionPieces: event.optionPieces,
        });
      } catch {
        // Best-effort — matches the base price_history write's failure posture.
      }
    }
  }

  async adjustStock(id: string, delta: number, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      quantity: increment(delta),
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async setStock(id: string, quantity: number, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      quantity,
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async deactivate(id: string, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      isActive: false,
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async reactivate(id: string, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      isActive: true,
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async recordPriceChange(
    productId: string,
    entry: Omit<PriceHistoryEntry, 'changedAt'>,
  ): Promise<void> {
    const data: Record<string, unknown> = {
      price: entry.price,
      cost: entry.cost,
      changedAt: serverTimestamp(),
      changedBy: entry.changedBy,
      reason: entry.reason,
    };
    // Conditionally included — a base entry must leave these keys ABSENT
    // (not present-with-null), so a plain field-presence check can tell
    // "base" apart from "no option data available".
    if (entry.optionId != null) data.optionId = entry.optionId;
    if (entry.optionLabel != null) data.optionLabel = entry.optionLabel;
    if (entry.optionPieces != null) data.optionPieces = entry.optionPieces;
    await addDoc(
      collection(this.db, FirestoreCollections.products, productId, Subcollections.priceHistory),
      data,
    );
  }
  async listPriceHistory(productId: string): Promise<PriceHistoryEntry[]> {
    const snap = await getDocs(
      query(
        collection(this.db, FirestoreCollections.products, productId, Subcollections.priceHistory),
        orderBy('changedAt', 'desc'),
        limit(50),
      ),
    );
    return snap.docs.map((d) => {
      const data = d.data();
      return {
        price: (data.price as number) ?? 0,
        cost: (data.cost as number) ?? 0,
        changedAt: toDate(data.changedAt) ?? new Date(0),
        changedBy: (data.changedBy as string) ?? '',
        reason: (data.reason as string | null) ?? null,
        note: (data.note as string | null) ?? null,
        optionId: (data.optionId as string | null | undefined) ?? null,
        optionLabel: (data.optionLabel as string | null | undefined) ?? null,
        optionPieces: (data.optionPieces as number | null | undefined) ?? null,
      };
    });
  }

  async listPriceChangesInRange(start: Date, end: Date, max = 500): Promise<PriceChangeEntry[]> {
    const snap = await getDocs(
      query(
        collectionGroup(this.db, Subcollections.priceHistory),
        where('changedAt', '>=', Timestamp.fromDate(start)),
        where('changedAt', '<=', Timestamp.fromDate(end)),
        orderBy('changedAt', 'desc'),
        limit(max),
      ),
    );
    return snap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        productId: d.ref.parent.parent!.id,
        price: (data.price as number) ?? 0,
        cost: (data.cost as number) ?? 0,
        changedAt: toDate(data.changedAt) ?? new Date(0),
        changedBy: (data.changedBy as string) ?? '',
        reason: (data.reason as string | null) ?? null,
        note: (data.note as string | null) ?? null,
        // Without these, every entry here looks like a base entry regardless
        // of what's in Firestore, and the (productId, optionId) report
        // grouping has nothing to key off.
        optionId: (data.optionId as string | null | undefined) ?? null,
        optionLabel: (data.optionLabel as string | null | undefined) ?? null,
        optionPieces: (data.optionPieces as number | null | undefined) ?? null,
      } satisfies PriceChangeEntry;
    });
  }
}

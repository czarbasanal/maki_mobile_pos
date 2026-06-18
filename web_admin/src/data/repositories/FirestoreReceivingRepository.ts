import {
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
import type { ProductRepository } from '@/domain/repositories/ProductRepository';
import type {
  BulkReceiveInput,
  ReceivingInput,
  ReceivingRepository,
  ReceivingResult,
} from '@/domain/repositories/ReceivingRepository';
import type { CostCode, Receiving, ReceivingItem } from '@/domain/entities';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { applyReceivedItems } from '@/data/receiving/applyReceivedItems';
import { classifiedToReceivable } from '@/domain/receiving/receivableItem';
import { resolveDraftItems } from '@/data/receiving/resolveDraftItems';
import { planReceive } from '@/data/receiving/planReceive';
import { executeReceivePlan } from '@/data/receiving/executeReceivePlan';
import { newProductId } from '@/data/products/productWrites';
import { receivingConverter } from '@/data/converters/receivingConverter';
import type { DateRange } from '@/domain/reports/dateRange';

// Firestore caps a writeBatch at 500 writes and a doc at 1MB. bulkReceive
// creates products individually (no batch limit there) but commits stock
// increments + the receiving doc in one batch, and embeds all items on the doc —
// so cap comfortably below both. The cap also bounds the orphan blast radius of
// a mid-import crash.
const MAX_BULK_RECEIVING_ITEMS = 400;
// complete() commits in ONE transaction: up to 3 writes per new/variation item
// (product + SKU claim + price history) + matched increments + the receiving
// doc — keep it well under the 500-write transaction cap.
const MAX_TRANSACTION_RECEIVING_ITEMS = 150;

/** Ensures every persisted item has an id and never a `undefined`
 *  `pendingNewProduct` (Firestore rejects undefined — ignoreUndefinedProperties
 *  is off), coercing the optional field to null like the converter does. */
function normalizeItems(items: ReceivingItem[]): ReceivingItem[] {
  return items.map((it) => ({
    ...it,
    id: it.id || crypto.randomUUID(),
    pendingNewProduct: it.pendingNewProduct ?? null,
  }));
}

export class FirestoreReceivingRepository implements ReceivingRepository {
  constructor(
    private readonly db: Firestore,
    private readonly products: ProductRepository,
  ) {}

  // NOTE: bulkReceive is intentionally NOT a single transaction. A large CSV can
  // create hundreds of products, and Firestore caps a transaction/batch at 500
  // writes — an atomic version would fail on big imports. So it keeps per-product
  // creation (each its own atomic create() with SKU-claim + collision-retry) plus
  // a chunked stock/receiving batch, accepting that a mid-import crash can leave
  // orphan products. complete() (small manual entries) IS fully atomic.
  async bulkReceive(input: BulkReceiveInput): Promise<ReceivingResult> {
    const { rows, supplier, cipher, actor } = input;
    const referenceNumber = await this.generateReferenceNumber();

    const receivables = rows
      .map(classifiedToReceivable)
      .filter((r): r is NonNullable<typeof r> => r !== null);
    if (receivables.length > MAX_BULK_RECEIVING_ITEMS) {
      throw new Error(
        `This import has ${receivables.length} items — the maximum per receiving is ` +
          `${MAX_BULK_RECEIVING_ITEMS}. Split it into smaller files.`,
      );
    }
    const outcome = await applyReceivedItems(receivables, this.products, {
      cipher,
      actor,
      supplier,
      knownSkus: input.products.map((p) => p.sku),
    });

    const batch = writeBatch(this.db);
    for (const [productId, delta] of outcome.increments) {
      batch.update(doc(this.db, FirestoreCollections.products, productId), {
        quantity: increment(delta),
        updatedBy: actor.id,
        updatedByName: actor.name,
        updatedAt: serverTimestamp(),
      });
    }
    const totalQuantity = outcome.items.reduce((n, it) => n + it.quantity, 0);
    const totalCost = outcome.items.reduce((n, it) => n + it.unitCost * it.quantity, 0);
    batch.set(doc(collection(this.db, FirestoreCollections.receivings)), {
      referenceNumber,
      supplierId: supplier?.id ?? null,
      supplierName: supplier?.name ?? null,
      items: outcome.items,
      totalCost,
      totalQuantity,
      status: 'completed',
      notes: null,
      createdBy: actor.id,
      createdByName: actor.name,
      completedBy: actor.id,
      createdAt: serverTimestamp(),
      completedAt: serverTimestamp(),
    });
    await batch.commit();

    return {
      referenceNumber,
      received: outcome.items.length,
      newProducts: outcome.newProducts,
      variations: outcome.variations,
      failed: outcome.failed.map((f) => ({ row: Number(f.ref), message: f.message })),
    };
  }

  // --- Read side: history list + detail ---

  private receivingsCol() {
    return collection(this.db, FirestoreCollections.receivings).withConverter(
      receivingConverter,
    );
  }

  async getById(id: string): Promise<Receiving | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.receivings, id).withConverter(receivingConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  watchAll(
    range: DateRange,
    onData: (records: Receiving[]) => void,
    onError?: (err: Error) => void,
  ): Unsubscribe {
    // createdAt range filter + orderBy are on the SAME field, so this needs
    // only the default single-field index (no composite index).
    return onSnapshot(
      query(
        this.receivingsCol(),
        where('createdAt', '>=', Timestamp.fromDate(range.start)),
        // `range.end` is an inclusive endOfDay() bound, so use '<=' to match the
        // sales/activity-log repos (a '<' would drop the day's final instant).
        where('createdAt', '<=', Timestamp.fromDate(range.end)),
        orderBy('createdAt', 'desc'),
      ),
      (snap) => onData(snap.docs.map((d) => d.data())),
      onError,
    );
  }

  watchDrafts(
    onData: (records: Receiving[]) => void,
    onError?: (err: Error) => void,
  ): Unsubscribe {
    // Equality filter only (no orderBy) → default single-field index; sort
    // newest-first client-side (drafts are few).
    return onSnapshot(
      query(this.receivingsCol(), where('status', '==', 'draft')),
      (snap) => {
        const drafts = snap.docs.map((d) => d.data());
        drafts.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        onData(drafts);
      },
      onError,
    );
  }

  async create(input: ReceivingInput, actorId: string): Promise<Receiving> {
    // Stock is applied only through complete() (which has the cost-code cipher),
    // so create() persists drafts only — a 'completed' create would write a
    // completed doc with no stock effects.
    if (input.status === 'completed') {
      throw new Error('create() writes drafts; call complete() to finalize and apply stock.');
    }
    const ref = doc(collection(this.db, FirestoreCollections.receivings));
    const referenceNumber = input.referenceNumber || (await this.generateReferenceNumber());
    const items = normalizeItems(input.items);
    await setDoc(ref, {
      referenceNumber,
      supplierId: input.supplierId,
      supplierName: input.supplierName,
      items,
      totalCost: input.totalCost,
      totalQuantity: input.totalQuantity,
      status: input.status,
      notes: input.notes,
      createdBy: actorId,
      createdByName: input.createdByName,
      completedBy: null,
      createdAt: serverTimestamp(),
      completedAt: null,
    });
    const snap = await getDoc(ref.withConverter(receivingConverter));
    return snap.data()!;
  }

  async update(id: string, input: ReceivingInput, actorId: string): Promise<void> {
    const ref = doc(this.db, FirestoreCollections.receivings, id);
    const snap = await getDoc(ref);
    if (!snap.exists()) throw new Error('Receiving not found');
    if (snap.data().status === 'completed') {
      throw new Error('Cannot edit a completed receiving');
    }
    const items = normalizeItems(input.items);
    await updateDoc(ref, {
      supplierId: input.supplierId,
      supplierName: input.supplierName,
      items,
      totalCost: input.totalCost,
      totalQuantity: input.totalQuantity,
      notes: input.notes,
      updatedBy: actorId,
    });
  }

  async complete(
    id: string,
    actor: { id: string; name: string | null },
    cipher: CostCode,
  ): Promise<void> {
    const ref = doc(this.db, FirestoreCollections.receivings, id);
    const snap = await getDoc(ref.withConverter(receivingConverter));
    const receiving = snap.exists() ? snap.data() : null;
    if (!receiving) throw new Error('Receiving not found');
    if (receiving.status === 'completed') return; // idempotent — never double-apply stock

    const products = await this.products.list();
    const receivables = resolveDraftItems(receiving.items, products);
    // resolveDraftItems drops existing-product lines whose product is gone. Refuse
    // to complete a partial receiving (it would be locked as completed, missing
    // items) — make the user edit the draft instead.
    if (receivables.length !== receiving.items.length) {
      throw new Error(
        'Some items reference products that no longer exist — edit the draft and try again.',
      );
    }
    if (receivables.length > MAX_TRANSACTION_RECEIVING_ITEMS) {
      throw new Error(
        `This receiving has ${receivables.length} items — the maximum is ` +
          `${MAX_TRANSACTION_RECEIVING_ITEMS}. Receive in smaller batches.`,
      );
    }
    const plan = planReceive(
      receivables,
      {
        cipher,
        actor,
        supplier: receiving.supplierId
          ? { id: receiving.supplierId, name: receiving.supplierName ?? '' }
          : null,
        knownSkus: products.map((p) => p.sku),
      },
      () => newProductId(this.db),
    );
    const totalQuantity = plan.items.reduce((n, it) => n + it.quantity, 0);
    const totalCost = plan.items.reduce((n, it) => n + it.unitCost * it.quantity, 0);

    // One atomic transaction: create products (+ claims + price history),
    // increment matched stock, and flip the draft to completed. Re-read the doc
    // inside the tx so a concurrent completion can't double-apply stock.
    await runTransaction(this.db, async (tx) => {
      const fresh = await tx.get(ref);
      if (fresh.exists() && fresh.data().status === 'completed') return;
      await executeReceivePlan(tx, this.db, plan, actor);
      tx.update(ref, {
        items: plan.items,
        totalQuantity,
        totalCost,
        status: 'completed',
        completedBy: actor.id,
        completedAt: serverTimestamp(),
      });
    });
  }

  // The unbounded list() is unused on web (history uses watchAll); keep stubbed.
  async list(): Promise<Receiving[]> {
    throw new Error('ReceivingRepository.list not implemented yet');
  }

  private async generateReferenceNumber(): Promise<string> {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
    const snap = await getDocs(
      query(
        collection(this.db, FirestoreCollections.receivings),
        where('createdAt', '>=', Timestamp.fromDate(start)),
        where('createdAt', '<', Timestamp.fromDate(end)),
      ),
    );
    const seq = snap.size + 1;
    const date = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(
      now.getDate(),
    ).padStart(2, '0')}`;
    return `RCV-${date}-${String(seq).padStart(3, '0')}`;
  }
}

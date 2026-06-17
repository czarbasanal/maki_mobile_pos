import {
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  onSnapshot,
  orderBy,
  query,
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
import type { CostCode, Receiving } from '@/domain/entities';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { applyReceivedItems } from '@/data/receiving/applyReceivedItems';
import { classifiedToReceivable } from '@/domain/receiving/receivableItem';
import { resolveDraftItems } from '@/data/receiving/resolveDraftItems';
import { receivingConverter } from '@/data/converters/receivingConverter';
import type { DateRange } from '@/domain/reports/dateRange';

export class FirestoreReceivingRepository implements ReceivingRepository {
  constructor(
    private readonly db: Firestore,
    private readonly products: ProductRepository,
  ) {}

  async bulkReceive(input: BulkReceiveInput): Promise<ReceivingResult> {
    const { rows, supplier, cipher, actor } = input;
    const referenceNumber = await this.generateReferenceNumber();

    const receivables = rows
      .map(classifiedToReceivable)
      .filter((r): r is NonNullable<typeof r> => r !== null);
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
    const ref = doc(collection(this.db, FirestoreCollections.receivings));
    const referenceNumber = input.referenceNumber || (await this.generateReferenceNumber());
    const items = input.items.map((it) => ({ ...it, id: it.id || crypto.randomUUID() }));
    const isCompleted = input.status === 'completed';
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
      completedBy: isCompleted ? actorId : null,
      createdAt: serverTimestamp(),
      completedAt: isCompleted ? serverTimestamp() : null,
    });
    const snap = await getDoc(ref.withConverter(receivingConverter));
    return snap.data()!;
  }

  async update(id: string, input: ReceivingInput, actorId: string): Promise<void> {
    const ref = doc(this.db, FirestoreCollections.receivings, id);
    const snap = await getDoc(ref);
    if (snap.exists() && snap.data().status === 'completed') {
      throw new Error('Cannot edit a completed receiving');
    }
    const items = input.items.map((it) => ({ ...it, id: it.id || crypto.randomUUID() }));
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
    const outcome = await applyReceivedItems(receivables, this.products, {
      cipher,
      actor,
      supplier: receiving.supplierId
        ? { id: receiving.supplierId, name: receiving.supplierName ?? '' }
        : null,
      knownSkus: products.map((p) => p.sku),
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
    batch.update(ref, {
      items: outcome.items,
      totalQuantity: outcome.items.reduce((n, it) => n + it.quantity, 0),
      totalCost: outcome.items.reduce((n, it) => n + it.unitCost * it.quantity, 0),
      status: 'completed',
      completedBy: actor.id,
      completedAt: serverTimestamp(),
    });
    await batch.commit();
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

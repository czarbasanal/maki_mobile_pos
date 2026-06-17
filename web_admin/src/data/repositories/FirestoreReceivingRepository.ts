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
  Timestamp,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
import type { ProductRepository } from '@/domain/repositories/ProductRepository';
import type {
  BulkReceiveInput,
  ReceivingRepository,
  ReceivingResult,
} from '@/domain/repositories/ReceivingRepository';
import type { Receiving } from '@/domain/entities';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { applyReceivedItems } from '@/data/receiving/applyReceivedItems';
import { classifiedToReceivable } from '@/domain/receiving/receivableItem';
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

  // Manual entry (create/complete) and the unbounded list() are a later slice.
  async list(): Promise<Receiving[]> {
    throw new Error('ReceivingRepository.list not implemented yet');
  }
  async create(): Promise<Receiving> {
    throw new Error('ReceivingRepository.create not implemented yet');
  }
  async complete(): Promise<void> {
    throw new Error('ReceivingRepository.complete not implemented yet');
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

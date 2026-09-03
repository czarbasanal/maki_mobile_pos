import {
  collection,
  doc,
  getDoc,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type {
  PurchaseOrderInput,
  PurchaseOrderRepository,
} from '@/domain/repositories/PurchaseOrderRepository';
import type { PurchaseOrder } from '@/domain/entities';
import {
  purchaseOrderTotalCost,
  purchaseOrderTotalQuantity,
} from '@/domain/entities';
import {
  formatPurchaseOrderNumber,
  purchaseOrderCounterKey,
} from '@/domain/purchaseOrders/purchaseOrderNumber';
import {
  purchaseOrderConverter,
  purchaseOrderItemsToMaps,
} from '@/data/converters/purchaseOrderConverter';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

export class FirestorePurchaseOrderRepository
  implements PurchaseOrderRepository
{
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.purchaseOrders).withConverter(
      purchaseOrderConverter,
    );
  }

  watchAll(
    callback: (orders: PurchaseOrder[]) => void,
    onError?: (e: Error) => void,
  ): Unsubscribe {
    return onSnapshot(
      query(this.col(), orderBy('createdAt', 'desc')),
      (snap) => callback(snap.docs.map((d) => d.data())),
      (e) => onError?.(e as Error),
    );
  }

  async getById(id: string): Promise<PurchaseOrder | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.purchaseOrders, id).withConverter(
        purchaseOrderConverter,
      ),
    );
    return snap.exists() ? snap.data() : null;
  }

  async create(input: PurchaseOrderInput): Promise<PurchaseOrder> {
    if (input.items.length === 0) {
      throw new Error('A purchase order needs at least one item');
    }
    const ref = doc(collection(this.db, FirestoreCollections.purchaseOrders));
    // Counter document, not a count of today's orders. Counting is how mobile
    // and receivings do it, and it hands two simultaneous creators the same
    // number; the transaction makes the allocation atomic instead.
    const counterRef = doc(
      this.db,
      FirestoreCollections.settings,
      'purchase_order_counters',
    );
    const now = new Date();
    const key = purchaseOrderCounterKey(now);

    await runTransaction(this.db, async (tx) => {
      const counterSnap = await tx.get(counterRef);
      const seq =
        (counterSnap.exists()
          ? ((counterSnap.data() as Record<string, number>)[key] ?? 0)
          : 0) + 1;
      tx.set(counterRef, { [key]: seq }, { merge: true });
      tx.set(ref, {
        referenceNumber: formatPurchaseOrderNumber(now, seq),
        // A buying list has no supplier of its own — it lives on the lines.
        supplierId: null,
        supplierName: null,
        items: purchaseOrderItemsToMaps(input.items),
        totalCost: purchaseOrderTotalCost(input.items),
        totalQuantity: purchaseOrderTotalQuantity(input.items),
        status: input.status,
        notes: input.notes,
        createdBy: input.createdBy,
        createdByName: input.createdByName,
        createdAt: serverTimestamp(),
        orderedAt: input.status === 'ordered' ? serverTimestamp() : null,
        receivedAt: null,
        receivingId: null,
        windowDays: input.windowDays,
        coverDays: input.coverDays,
      });
    });

    const created = await this.getById(ref.id);
    if (!created) throw new Error('Failed to load the created purchase order');
    return created;
  }

  async update(
    id: string,
    patch: Partial<Pick<PurchaseOrder, 'items' | 'notes' | 'status'>>,
    actorId: string,
  ): Promise<void> {
    const data: Record<string, unknown> = { updatedBy: actorId };
    if (patch.items !== undefined) {
      data.items = purchaseOrderItemsToMaps(patch.items);
      data.totalCost = purchaseOrderTotalCost(patch.items);
      data.totalQuantity = purchaseOrderTotalQuantity(patch.items);
    }
    if (patch.notes !== undefined) data.notes = patch.notes;
    if (patch.status !== undefined) {
      data.status = patch.status;
      // Stamped once, when the list stops being edited and goes out.
      if (patch.status === 'ordered') data.orderedAt = serverTimestamp();
    }
    await updateDoc(
      doc(this.db, FirestoreCollections.purchaseOrders, id),
      data,
    );
  }

  async cancel(id: string, actorId: string): Promise<void> {
    // Kept, not deleted: a list that vanishes should always be something
    // somebody did on purpose, and visibly.
    await updateDoc(doc(this.db, FirestoreCollections.purchaseOrders, id), {
      status: 'cancelled',
      updatedBy: actorId,
    });
  }
}

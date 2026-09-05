// Mirror of mobile's VoidRequestRepositoryImpl. The
// transaction pre-allocates the request doc, then claims
// void_request_pending/{saleId} — the hard duplicate lock — and writes both
// atomically. Rules require requestedBy == auth.uid and status == 'pending'.
import {
  collection,
  doc,
  getDocs,
  limit as fsLimit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  Timestamp,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
import type {
  VoidRequestCreateInput,
  VoidRequestRepository,
  VoidRequestResolveInput,
} from '@/domain/repositories/VoidRequestRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { VoidRequest } from '@/domain/entities';
import { voidRequestConverter } from '@/data/converters/voidRequestConverter';

const REQUESTS = 'void_requests';
const PENDING = 'void_request_pending';

export class FirestoreVoidRequestRepository implements VoidRequestRepository {
  constructor(private readonly db: Firestore) {}

  async createRequest(input: VoidRequestCreateInput): Promise<void> {
    const requestRef = doc(collection(this.db, REQUESTS));
    const claimRef = doc(this.db, PENDING, input.saleId);
    await runTransaction(this.db, async (tx) => {
      const claim = await tx.get(claimRef);
      if (claim.exists()) {
        throw new Error('A void request for this sale is already pending');
      }
      tx.set(claimRef, {
        requestId: requestRef.id,
        requestedBy: input.requestedBy,
        createdAt: serverTimestamp(),
      });
      tx.set(requestRef, {
        saleId: input.saleId,
        saleNumber: input.saleNumber,
        saleGrandTotal: input.saleGrandTotal,
        requestedBy: input.requestedBy,
        requestedByName: input.requestedByName,
        requestedByRole: input.requestedByRole,
        reason: input.reason,
        status: 'pending',
        read: false,
        createdAt: serverTimestamp(),
        ...(input.itemsSummary !== null ? { itemsSummary: input.itemsSummary } : {}),
      });
    });
  }

  async hasPendingForSale(saleId: string): Promise<boolean> {
    const snap = await getDocs(
      query(
        collection(this.db, REQUESTS),
        where('saleId', '==', saleId),
        where('status', '==', 'pending'),
        fsLimit(1),
      ),
    );
    return !snap.empty;
  }

  watchPending(callback: (requests: VoidRequest[]) => void, onError?: (e: Error) => void): Unsubscribe {
    const q = query(
      collection(this.db, REQUESTS).withConverter(voidRequestConverter),
      where('status', '==', 'pending'),
    );
    return onSnapshot(
      q,
      (snap) => callback(snap.docs.map((d) => d.data())),
      (e) => onError?.(e as Error),
    );
  }

  watchResolved(
    range: { start: Date; end: Date },
    callback: (requests: VoidRequest[]) => void,
    onError?: (e: Error) => void,
  ): Unsubscribe {
    // Single-field range on resolvedAt — no composite index. Rows resolved
    // before resolvedAt was recorded (null) are not in scope of any range.
    const q = query(
      collection(this.db, REQUESTS).withConverter(voidRequestConverter),
      where('resolvedAt', '>=', Timestamp.fromDate(range.start)),
      where('resolvedAt', '<=', Timestamp.fromDate(range.end)),
      orderBy('resolvedAt', 'desc'),
    );
    return onSnapshot(
      q,
      (snap) => callback(snap.docs.map((d) => d.data())),
      (e) => onError?.(e as Error),
    );
  }

  watchRequests(
    callback: (requests: VoidRequest[]) => void,
    onError?: (e: Error) => void,
    limit = 50,
  ): Unsubscribe {
    const q = query(
      collection(this.db, REQUESTS).withConverter(voidRequestConverter),
      orderBy('createdAt', 'desc'),
      fsLimit(limit),
    );
    return onSnapshot(
      q,
      (snap) => callback(snap.docs.map((d) => d.data())),
      (e) => onError?.(e as Error),
    );
  }

  async resolve(input: VoidRequestResolveInput): Promise<void> {
    // One batch, mirroring mobile: the status write and the release of the
    // per-sale claim must not be able to land separately, or the sale is left
    // permanently un-requestable with no pending request to show for it.
    const batch = writeBatch(this.db);
    batch.update(doc(this.db, REQUESTS, input.requestId), {
      status: input.status,
      read: true,
      resolvedBy: input.resolvedBy,
      resolvedByName: input.resolvedByName,
      resolvedAt: serverTimestamp(),
      ...(input.rejectionReason != null
        ? { rejectionReason: input.rejectionReason }
        : {}),
    });
    // Idempotent: requests predating the claim collection have none, and
    // deleting a missing doc is a no-op.
    batch.delete(doc(this.db, PENDING, input.saleId));
    await batch.commit();
  }

  async markAllRead(): Promise<void> {
    // Capped at the 500-write batch limit. Marking read is a badge nicety, so
    // a partial pass is fine — the next open clears the rest — but exceeding
    // the limit would fail the whole batch and leave the badge stuck.
    const snap = await getDocs(
      query(
        collection(this.db, REQUESTS),
        where('read', '==', false),
        fsLimit(500),
      ),
    );
    if (snap.empty) return;
    const batch = writeBatch(this.db);
    snap.docs.forEach((d) => batch.update(d.ref, { read: true }));
    await batch.commit();
  }
}

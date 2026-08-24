// Mirror of mobile's VoidRequestRepositoryImpl (create side only). The
// transaction pre-allocates the request doc, then claims
// void_request_pending/{saleId} — the hard duplicate lock — and writes both
// atomically. Rules require requestedBy == auth.uid and status == 'pending'.
import {
  collection,
  doc,
  getDocs,
  limit,
  query,
  runTransaction,
  serverTimestamp,
  where,
  type Firestore,
} from 'firebase/firestore';
import type {
  VoidRequestCreateInput,
  VoidRequestRepository,
} from '@/domain/repositories/VoidRequestRepository';

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
        limit(1),
      ),
    );
    return !snap.empty;
  }
}

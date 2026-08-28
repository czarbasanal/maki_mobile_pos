import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { VoidRequest } from '@/domain/entities';
import { voidRequestStatusFromString } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

// Reads only. Requests are created inside a transaction and resolved in a
// batch (both need the pending-claim doc alongside the request), so every
// write path lives in FirestoreVoidRequestRepository.
export const voidRequestConverter: FirestoreDataConverter<VoidRequest> = {
  toFirestore() {
    throw new Error(
      'voidRequestConverter is read-only — write void requests via FirestoreVoidRequestRepository',
    );
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): VoidRequest {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      saleId: d.saleId ?? '',
      saleNumber: d.saleNumber ?? '',
      saleGrandTotal: Number(d.saleGrandTotal ?? 0),
      requestedBy: d.requestedBy ?? '',
      requestedByName: d.requestedByName ?? '',
      requestedByRole: d.requestedByRole ?? '',
      reason: d.reason ?? '',
      status: voidRequestStatusFromString(d.status),
      read: d.read === true,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      resolvedBy: d.resolvedBy ?? null,
      resolvedByName: d.resolvedByName ?? null,
      resolvedAt: toDate(d.resolvedAt),
      rejectionReason: d.rejectionReason ?? null,
      itemsSummary: d.itemsSummary ?? null,
    };
  },
};

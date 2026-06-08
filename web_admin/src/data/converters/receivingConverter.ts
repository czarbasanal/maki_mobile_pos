// Mirror of lib/data/models/receiving_model.dart fromFirestore/toMap. Reads the
// `receivings` docs that bulkReceive() writes (items embedded on the doc).
import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Receiving, ReceivingItem, ReceivingStatus } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

const VALID_STATUS: ReceivingStatus[] = ['draft', 'completed', 'cancelled'];

function parseStatus(value: unknown): ReceivingStatus {
  return VALID_STATUS.includes(value as ReceivingStatus)
    ? (value as ReceivingStatus)
    : 'completed';
}

function parseItems(value: unknown): ReceivingItem[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const it = raw as Record<string, unknown>;
    return {
      id: (it.id as string) ?? '',
      productId: (it.productId as string | null) ?? null,
      sku: (it.sku as string) ?? '',
      name: (it.name as string) ?? '',
      quantity: Number(it.quantity ?? 0),
      unit: (it.unit as string) ?? 'pcs',
      unitCost: Number(it.unitCost ?? 0),
      costCode: (it.costCode as string) ?? '',
      isNewVariation: Boolean(it.isNewVariation ?? false),
      newProductId: (it.newProductId as string | null) ?? null,
      notes: (it.notes as string | null) ?? null,
    };
  });
}

export const receivingConverter: FirestoreDataConverter<Receiving> = {
  toFirestore(r) {
    return {
      referenceNumber: r.referenceNumber,
      supplierId: r.supplierId,
      supplierName: r.supplierName,
      items: r.items,
      totalCost: r.totalCost,
      totalQuantity: r.totalQuantity,
      status: r.status,
      notes: r.notes,
      createdBy: r.createdBy,
      createdByName: r.createdByName,
      completedBy: r.completedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Receiving {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      referenceNumber: d.referenceNumber ?? '',
      supplierId: d.supplierId ?? null,
      supplierName: d.supplierName ?? null,
      items: parseItems(d.items),
      totalCost: Number(d.totalCost ?? 0),
      totalQuantity: Number(d.totalQuantity ?? 0),
      status: parseStatus(d.status),
      notes: d.notes ?? null,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      completedAt: toDate(d.completedAt),
      createdBy: d.createdBy ?? '',
      createdByName: d.createdByName ?? '',
      completedBy: d.completedBy ?? null,
    };
  },
};

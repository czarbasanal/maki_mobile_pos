import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { PurchaseOrder, PurchaseOrderItem } from '@/domain/entities';
import { purchaseOrderStatusFromString } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

/** Parse the inline `items` array. */
export function parsePurchaseOrderItems(value: unknown): PurchaseOrderItem[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw, i) => {
    const m = (raw ?? {}) as Record<string, unknown>;
    return {
      id: typeof m.id === 'string' ? m.id : `item-${i}`,
      productId: typeof m.productId === 'string' ? m.productId : '',
      sku: typeof m.sku === 'string' ? m.sku : '',
      name: typeof m.name === 'string' ? m.name : '',
      quantity: Number(m.quantity ?? 0),
      unit: typeof m.unit === 'string' ? m.unit : 'pcs',
      unitCost: Number(m.unitCost ?? 0),
      costCode: typeof m.costCode === 'string' ? m.costCode : '',
      // Absent on every order mobile has written, and on any line whose
      // supplier has not been decided yet.
      supplierId: typeof m.supplierId === 'string' ? m.supplierId : null,
      supplierName: typeof m.supplierName === 'string' ? m.supplierName : null,
    };
  });
}

export function purchaseOrderItemsToMaps(items: PurchaseOrderItem[]): object[] {
  return items.map((i) => ({
    id: i.id,
    productId: i.productId,
    sku: i.sku,
    name: i.name,
    quantity: i.quantity,
    unit: i.unit,
    unitCost: i.unitCost,
    costCode: i.costCode,
    supplierId: i.supplierId,
    supplierName: i.supplierName,
  }));
}

// Reads only — writes go through FirestorePurchaseOrderRepository, which
// allocates the reference number in the same transaction as the create.
export const purchaseOrderConverter: FirestoreDataConverter<PurchaseOrder> = {
  toFirestore() {
    throw new Error(
      'purchaseOrderConverter is read-only — write via FirestorePurchaseOrderRepository',
    );
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): PurchaseOrder {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      referenceNumber: d.referenceNumber ?? '',
      supplierId: d.supplierId ?? null,
      supplierName: d.supplierName ?? null,
      items: parsePurchaseOrderItems(d.items),
      totalCost: Number(d.totalCost ?? 0),
      totalQuantity: Number(d.totalQuantity ?? 0),
      status: purchaseOrderStatusFromString(d.status),
      notes: d.notes ?? null,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      createdBy: d.createdBy ?? '',
      createdByName: d.createdByName ?? '',
      orderedAt: toDate(d.orderedAt),
      receivedAt: toDate(d.receivedAt),
      receivingId: d.receivingId ?? null,
      windowDays: typeof d.windowDays === 'number' ? d.windowDays : null,
      coverDays: typeof d.coverDays === 'number' ? d.coverDays : null,
    };
  },
};

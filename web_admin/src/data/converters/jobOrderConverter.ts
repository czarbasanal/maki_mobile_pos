import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { JobOrder, SaleItem } from '@/domain/entities';
import { discountTypeFromString } from '@/domain/enums';
import { requireDate, toDate } from './timestamps';
import { parseLaborLines } from './laborLines';
import { parseFeeLines } from './feeLines';

/** Serialize cart/job order items to inline Firestore maps (id included). */
export function jobOrderItemsToMaps(items: SaleItem[]): object[] {
  return items.map((it) => ({
    id: it.id,
    productId: it.productId,
    sku: it.sku,
    name: it.name,
    unitPrice: it.unitPrice,
    unitCost: it.unitCost,
    quantity: it.quantity,
    discountValue: it.discountValue,
    unit: it.unit,
  }));
}

/** Parse an inline `items` array from Firestore into SaleItem[]. */
export function parseJobOrderItems(value: unknown): SaleItem[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw, i) => {
    const m = (raw ?? {}) as Record<string, unknown>;
    return {
      id: typeof m.id === 'string' ? m.id : `item-${i}`,
      productId: typeof m.productId === 'string' ? m.productId : '',
      sku: typeof m.sku === 'string' ? m.sku : '',
      name: typeof m.name === 'string' ? m.name : '',
      unitPrice: Number(m.unitPrice ?? 0),
      unitCost: Number(m.unitCost ?? 0),
      quantity: Number(m.quantity ?? 0),
      discountValue: Number(m.discountValue ?? 0),
      unit: typeof m.unit === 'string' ? m.unit : 'pcs',
    };
  });
}

// Reads use this converter; writes go through the repository inline (so they can
// use serverTimestamp and serialize items/labor to maps). toFirestore is required
// by the type but must never be used — fail loudly if someone wires up a
// `.withConverter(...).set(...)` write path instead of the repository.
export const jobOrderConverter: FirestoreDataConverter<JobOrder> = {
  toFirestore() {
    throw new Error('jobOrderConverter is read-only — write jobOrders via FirestoreJobOrderRepository');
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): JobOrder {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: typeof d.name === 'string' && d.name ? d.name : 'Unnamed Job Order',
      items: parseJobOrderItems(d.items),
      laborLines: parseLaborLines(d.laborLines),
      feeLines: parseFeeLines(d.feeLines),
      mechanicId: d.mechanicId ?? null,
      mechanicName: d.mechanicName ?? null,
      discountType: discountTypeFromString(d.discountType),
      createdBy: d.createdBy ?? '',
      createdByName: d.createdByName ?? '',
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      updatedBy: d.updatedBy ?? null,
      isConverted: d.isConverted ?? false,
      convertedToSaleId: d.convertedToSaleId ?? null,
      convertedAt: toDate(d.convertedAt),
      notes: d.notes ?? null,
    };
  },
};

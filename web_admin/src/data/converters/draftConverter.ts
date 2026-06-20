import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Draft, SaleItem } from '@/domain/entities';
import { discountTypeFromString } from '@/domain/enums';
import { requireDate, toDate } from './timestamps';
import { parseLaborLines } from './laborLines';

/** Serialize cart/draft items to inline Firestore maps (id included). */
export function draftItemsToMaps(items: SaleItem[]): object[] {
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
export function parseDraftItems(value: unknown): SaleItem[] {
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
// use serverTimestamp). toFirestore is required by the type but unused on write.
export const draftConverter: FirestoreDataConverter<Draft> = {
  // Pass-through (mirrors saleConverter); real writes serialize inline in the
  // repository via draftItemsToMaps / laborLinesToMaps.
  toFirestore(d) {
    return {
      name: d.name,
      items: d.items,
      laborLines: d.laborLines,
      mechanicId: d.mechanicId,
      mechanicName: d.mechanicName,
      discountType: d.discountType,
      createdBy: d.createdBy,
      createdByName: d.createdByName,
      updatedBy: d.updatedBy,
      isConverted: d.isConverted,
      convertedToSaleId: d.convertedToSaleId,
      notes: d.notes,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Draft {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: typeof d.name === 'string' && d.name ? d.name : 'Unnamed Draft',
      items: parseDraftItems(d.items),
      laborLines: parseLaborLines(d.laborLines),
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

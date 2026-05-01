// Mirror of lib/data/models/sale_item_model.dart. Items live in
// sales/{saleId}/items/{itemId}.

import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { SaleItem } from '@/domain/entities';

export const saleItemConverter: FirestoreDataConverter<SaleItem> = {
  toFirestore(item) {
    return {
      productId: item.productId,
      sku: item.sku,
      name: item.name,
      unitPrice: item.unitPrice,
      unitCost: item.unitCost,
      quantity: item.quantity,
      discountValue: item.discountValue,
      unit: item.unit,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): SaleItem {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      productId: d.productId ?? '',
      sku: d.sku ?? '',
      name: d.name ?? '',
      unitPrice: Number(d.unitPrice ?? 0),
      unitCost: Number(d.unitCost ?? 0),
      quantity: Number(d.quantity ?? 0),
      discountValue: Number(d.discountValue ?? 0),
      unit: d.unit ?? 'pcs',
    };
  },
};

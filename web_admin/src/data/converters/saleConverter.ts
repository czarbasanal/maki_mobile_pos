// Mirror of lib/data/models/sale_model.dart fromMap/toMap. Items are NOT
// stored on the sale document — they live in the `items` subcollection and
// must be loaded separately by the repository.

import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Sale } from '@/domain/entities';
import {
  discountTypeFromString,
  paymentMethodFromString,
  saleStatusFromString,
} from '@/domain/enums';
import { requireDate, toDate } from './timestamps';

export const saleConverter: FirestoreDataConverter<Sale> = {
  toFirestore(sale) {
    return {
      saleNumber: sale.saleNumber,
      discountType: sale.discountType,
      paymentMethod: sale.paymentMethod,
      amountReceived: sale.amountReceived,
      changeGiven: sale.changeGiven,
      status: sale.status,
      cashierId: sale.cashierId,
      cashierName: sale.cashierName,
      draftId: sale.draftId,
      notes: sale.notes,
      voidedBy: sale.voidedBy,
      voidedByName: sale.voidedByName,
      voidReason: sale.voidReason,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Sale {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      saleNumber: d.saleNumber ?? '',
      items: [], // loaded separately from the items subcollection
      discountType: discountTypeFromString(d.discountType),
      paymentMethod: paymentMethodFromString(d.paymentMethod),
      amountReceived: Number(d.amountReceived ?? 0),
      changeGiven: Number(d.changeGiven ?? 0),
      status: saleStatusFromString(d.status),
      cashierId: d.cashierId ?? '',
      cashierName: d.cashierName ?? '',
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      draftId: d.draftId ?? null,
      notes: d.notes ?? null,
      voidedAt: toDate(d.voidedAt),
      voidedBy: d.voidedBy ?? null,
      voidedByName: d.voidedByName ?? null,
      voidReason: d.voidReason ?? null,
    };
  },
};

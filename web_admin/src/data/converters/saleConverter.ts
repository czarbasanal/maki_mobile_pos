// Mirror of lib/data/models/sale_model.dart fromMap/toMap. Items are NOT
// stored on the sale document — they live in the `items` subcollection and
// must be loaded separately by the repository.

import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { LaborLine, Sale } from '@/domain/entities';
import {
  type PaymentMethod,
  discountTypeFromString,
  paymentMethodFromString,
  realTenderMethods,
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
      laborLines: sale.laborLines,
      mechanicId: sale.mechanicId,
      mechanicName: sale.mechanicName,
      tenders: sale.tenders,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Sale {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      saleNumber: d.saleNumber ?? '',
      items: [], // loaded separately from the items subcollection
      laborLines: parseLaborLines(d.laborLines),
      mechanicId: d.mechanicId ?? null,
      mechanicName: d.mechanicName ?? null,
      tenders: parseTenders(d.tenders),
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

function parseLaborLines(value: unknown): LaborLine[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw, i) => {
    const m = (raw ?? {}) as Record<string, unknown>;
    return {
      id: typeof m.id === 'string' ? m.id : `labor-${i}`,
      description: typeof m.description === 'string' ? m.description : '',
      fee: Number(m.fee ?? 0),
    };
  });
}

function parseTenders(value: unknown): Partial<Record<PaymentMethod, number>> {
  if (value == null || typeof value !== 'object') return {};
  const out: Partial<Record<PaymentMethod, number>> = {};
  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    if ((realTenderMethods as string[]).includes(key)) {
      out[key as PaymentMethod] = Number(raw ?? 0);
    }
  }
  return out;
}

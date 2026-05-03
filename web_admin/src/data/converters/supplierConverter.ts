// Mirror of lib/data/models/supplier_model.dart. Note: searchKeywords is
// generated on every write (not stored on the entity) so we keep the Flutter
// app's array-contains queries working.

import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Supplier } from '@/domain/entities';
import { transactionTypeFromString } from '@/domain/enums';
import { supplierSearchKeywords } from '@/core/utils/searchKeywords';
import { requireDate, toDate } from './timestamps';

export const supplierConverter: FirestoreDataConverter<Supplier> = {
  toFirestore(s) {
    return {
      name: s.name,
      address: s.address,
      contactPerson: s.contactPerson,
      contactNumber: s.contactNumber,
      alternativeNumber: s.alternativeNumber,
      email: s.email,
      transactionType: s.transactionType,
      isActive: s.isActive,
      notes: s.notes,
      productCount: s.productCount,
      totalInventoryValue: s.totalInventoryValue,
      createdBy: s.createdBy,
      updatedBy: s.updatedBy,
      // Cast — toFirestore receives WithFieldValue<T> by default, but we
      // never feed FieldValue placeholders through this code path.
      searchKeywords: supplierSearchKeywords(
        s.name as string,
        (s.contactPerson as string | null | undefined) ?? null,
        (s.address as string | null | undefined) ?? null,
      ),
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Supplier {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: d.name ?? '',
      address: d.address ?? null,
      contactPerson: d.contactPerson ?? null,
      contactNumber: d.contactNumber ?? null,
      alternativeNumber: d.alternativeNumber ?? null,
      email: d.email ?? null,
      transactionType: transactionTypeFromString(d.transactionType),
      isActive: d.isActive ?? true,
      notes: d.notes ?? null,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      createdBy: d.createdBy ?? null,
      updatedBy: d.updatedBy ?? null,
      productCount: Number(d.productCount ?? 0),
      totalInventoryValue: Number(d.totalInventoryValue ?? 0),
    };
  },
};

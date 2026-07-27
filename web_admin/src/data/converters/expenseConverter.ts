import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Expense } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

// Mirror of lib/data/models/expense_model.dart's field set (minus paidVia,
// which the web admin doesn't yet surface). Reads use this converter; writes
// go through the repository inline (so they can use serverTimestamp).
// toFirestore is required by the type but unused on the write path.
export const expenseConverter: FirestoreDataConverter<Expense> = {
  toFirestore(e) {
    return {
      description: e.description,
      amount: e.amount,
      category: e.category,
      notes: e.notes,
      receiptNumber: e.receiptNumber,
      receiptImageUrl: e.receiptImageUrl,
      createdBy: e.createdBy,
      createdByName: e.createdByName,
      updatedBy: e.updatedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Expense {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      description: d.description ?? '',
      amount: (d.amount as number | undefined) ?? 0,
      category: d.category ?? 'General',
      date: requireDate(d.date, 'date'),
      notes: d.notes ?? null,
      receiptNumber: d.receiptNumber ?? null,
      receiptImageUrl: d.receiptImageUrl ?? null,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      createdBy: d.createdBy ?? '',
      createdByName: d.createdByName ?? '',
      updatedBy: d.updatedBy ?? null,
    };
  },
};

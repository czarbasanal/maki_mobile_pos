import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  type Firestore,
} from 'firebase/firestore';
import type {
  ExpenseCreateInput,
  ExpenseListFilters,
  ExpenseRepository,
} from '@/domain/repositories/ExpenseRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Expense } from '@/domain/entities';
import { expenseConverter } from '@/data/converters/expenseConverter';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

export class FirestoreExpenseRepository implements ExpenseRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.expenses).withConverter(expenseConverter);
  }

  newExpenseId(): string {
    return doc(collection(this.db, FirestoreCollections.expenses)).id;
  }

  async getById(id: string): Promise<Expense | null> {
    const ref = doc(this.db, FirestoreCollections.expenses, id).withConverter(expenseConverter);
    const snap = await getDoc(ref);
    return snap.exists() ? snap.data() : null;
  }

  // Range/category filter on Expense.date — the semantic expense date, not
  // createdAt — matching lib/data/repositories/expense_repository_impl.dart's
  // getExpenses() query so mobile and web read the same window.
  async list(filters: ExpenseListFilters = {}): Promise<Expense[]> {
    const constraints = [];
    if (filters.start) {
      constraints.push(where('date', '>=', Timestamp.fromDate(filters.start)));
    }
    if (filters.end) {
      constraints.push(where('date', '<=', Timestamp.fromDate(filters.end)));
    }
    if (filters.category) {
      constraints.push(where('category', '==', filters.category));
    }
    constraints.push(orderBy('date', 'desc'));

    const snap = await getDocs(query(this.col(), ...constraints));
    return snap.docs.map((d) => d.data());
  }

  watchAll(callback: (expenses: Expense[]) => void): Unsubscribe {
    const q = query(this.col(), orderBy('date', 'desc'));
    return onSnapshot(q, (snap) => callback(snap.docs.map((d) => d.data())));
  }

  async create(input: ExpenseCreateInput, actorId: string, actorName: string): Promise<Expense> {
    const { id: presetId, ...fields } = input;
    const data = {
      description: fields.description,
      amount: fields.amount,
      category: fields.category,
      date: Timestamp.fromDate(fields.date),
      paidVia: fields.paidVia,
      notes: fields.notes,
      receiptNumber: fields.receiptNumber,
      receiptImageUrl: fields.receiptImageUrl,
      createdAt: serverTimestamp(),
      createdBy: actorId,
      createdByName: actorName,
    };
    const ref = presetId
      ? doc(this.db, FirestoreCollections.expenses, presetId)
      : doc(collection(this.db, FirestoreCollections.expenses));
    await setDoc(ref, data);

    const created = await this.getById(ref.id);
    if (!created) throw new Error('Failed to load the created expense');
    return created;
  }

  async update(
    id: string,
    input: Partial<
      Omit<Expense, 'id' | 'createdAt' | 'createdBy' | 'createdByName' | 'updatedBy' | 'updatedByName'>
    >,
    actorId: string,
    actorName: string,
  ): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    };
    if (input.description !== undefined) data.description = input.description;
    if (input.amount !== undefined) data.amount = input.amount;
    if (input.category !== undefined) data.category = input.category;
    if (input.date !== undefined) data.date = Timestamp.fromDate(input.date);
    if (input.paidVia !== undefined) data.paidVia = input.paidVia;
    if (input.notes !== undefined) data.notes = input.notes;
    if (input.receiptNumber !== undefined) data.receiptNumber = input.receiptNumber;
    if (input.receiptImageUrl !== undefined) data.receiptImageUrl = input.receiptImageUrl;
    await updateDoc(doc(this.db, FirestoreCollections.expenses, id), data);
  }

  async delete(id: string): Promise<void> {
    await deleteDoc(doc(this.db, FirestoreCollections.expenses, id));
  }
}

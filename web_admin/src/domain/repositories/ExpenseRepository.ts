import type { Expense } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface ExpenseListFilters {
  /** Range bounds apply to Expense.date (the semantic expense date), not
   *  createdAt — mirrors the mobile ExpenseRepositoryImpl.getExpenses query. */
  start?: Date;
  end?: Date;
  category?: string;
}

export type ExpenseCreateInput = Omit<
  Expense,
  'id' | 'createdAt' | 'updatedAt' | 'updatedBy'
> & {
  /** A preset id (from newExpenseId()) lets the caller upload a receipt photo
   *  BEFORE the doc exists, then create() lands the doc on that same id.
   *  Omitted = Firestore auto-generates one. */
  id?: string;
};

export interface ExpenseRepository {
  getById(id: string): Promise<Expense | null>;
  list(filters?: ExpenseListFilters): Promise<Expense[]>;
  watchAll(callback: (expenses: Expense[]) => void): Unsubscribe;
  /** Pre-allocates a document id — see ExpenseCreateInput.id. */
  newExpenseId(): string;
  create(input: ExpenseCreateInput, actorId: string, actorName: string): Promise<Expense>;
  update(id: string, input: Partial<Omit<Expense, 'id' | 'createdAt' | 'createdBy' | 'createdByName'>>, actorId: string): Promise<void>;
  delete(id: string): Promise<void>;
}

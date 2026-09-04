import type { Expense } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface ExpenseListFilters {
  /** Range bounds apply to Expense.date (the semantic expense date), not
   *  createdAt — mirrors the mobile ExpenseRepositoryImpl.getExpenses query. */
  start?: Date;
  end?: Date;
}

export type ExpenseCreateInput = Omit<
  Expense,
  'id' | 'createdAt' | 'updatedAt' | 'updatedBy' | 'updatedByName'
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
  /** actorName is stamped as updatedByName, same posture as updatedBy —
   *  never trust a client-supplied value in the patch itself. */
  update(
    id: string,
    input: Partial<Omit<Expense, 'id' | 'createdAt' | 'createdBy' | 'createdByName' | 'updatedBy' | 'updatedByName'>>,
    actorId: string,
    actorName: string,
  ): Promise<void>;
  delete(id: string): Promise<void>;
}

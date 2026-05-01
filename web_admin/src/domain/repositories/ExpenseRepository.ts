import type { Expense } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface ExpenseRepository {
  getById(id: string): Promise<Expense | null>;
  list(start?: Date, end?: Date): Promise<Expense[]>;
  watchAll(callback: (expenses: Expense[]) => void): Unsubscribe;
  create(input: Omit<Expense, 'id' | 'createdAt' | 'updatedAt' | 'updatedBy'>, actorId: string, actorName: string): Promise<Expense>;
  update(id: string, input: Partial<Omit<Expense, 'id' | 'createdAt' | 'createdBy' | 'createdByName'>>, actorId: string): Promise<void>;
  delete(id: string): Promise<void>;
}

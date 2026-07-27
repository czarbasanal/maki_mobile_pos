// Mirror of lib/domain/entities/expense_entity.dart.
export interface Expense {
  id: string;
  description: string;
  amount: number;
  category: string;
  date: Date;
  notes: string | null;
  receiptNumber: string | null;
  /** Photo of the physical receipt (Storage download URL), if any. */
  receiptImageUrl: string | null;
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string;
  createdByName: string;
  updatedBy: string | null;
}

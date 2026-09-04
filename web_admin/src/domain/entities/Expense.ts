import type { PaymentMethod } from '../enums/PaymentMethod';

// Mirror of lib/domain/entities/expense_entity.dart.
export interface Expense {
  id: string;
  description: string;
  amount: number;
  category: string;
  date: Date;
  /** Which payment method funded this expense. Mirrors expense_entity.dart's
   *  paidVia (defaults to 'cash' on read — see expenseConverter). */
  paidVia: PaymentMethod;
  notes: string | null;
  receiptNumber: string | null;
  /** Photo of the physical receipt (Storage download URL), if any. */
  receiptImageUrl: string | null;
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string;
  createdByName: string;
  updatedBy: string | null;
  /** Display name of the actor who last saved this expense — stamped by the
   *  repository from the session, same posture as Product.updatedByName.
   *  Null until the first edit, or on a legacy doc from before this field
   *  existed (Record history then shows the raw updatedAt with no name). */
  updatedByName: string | null;
}

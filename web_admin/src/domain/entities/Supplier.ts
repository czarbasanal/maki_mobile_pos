// Mirror of lib/domain/entities/supplier_entity.dart.
import type { TransactionType } from '../enums';

export interface Supplier {
  id: string;
  name: string;
  address: string | null;
  contactPerson: string | null;
  contactNumber: string | null;
  alternativeNumber: string | null;
  email: string | null;
  transactionType: TransactionType;
  isActive: boolean;
  notes: string | null;
  /** Typical days from order to delivery; null = unknown. The reorder engine
   *  falls back to a default when null. */
  leadTimeDays: number | null;
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
  productCount: number;
  totalInventoryValue: number;
}

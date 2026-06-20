import type { Sale } from '@/domain/entities/Sale';
import type { User } from '@/domain/entities/User';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { CartLine } from '@/domain/sales/cart';
import type { DiscountType } from '@/domain/enums/DiscountType';
import type { PaymentMethod } from '@/domain/enums/PaymentMethod';
import { SaleStatus } from '@/domain/enums/SaleStatus';

export interface CheckoutInput {
  lines: CartLine[];
  discountType: DiscountType;
  paymentMethod: PaymentMethod;
  tenders: Partial<Record<PaymentMethod, number>>;
  amountReceived: number;
  changeGiven: number;
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
}

/** Compose the create-payload for a completed sale from cashier input + actor.
 *  Pure: the repo generates `saleNumber`/timestamps inside its transaction. */
export function buildSaleInput(
  input: CheckoutInput,
  actor: User,
): Omit<Sale, 'id' | 'createdAt' | 'updatedAt'> {
  const cashierName = actor.displayName.trim() || actor.email;
  return {
    saleNumber: '', // generated inside the repo transaction
    items: input.lines,
    laborLines: input.laborLines,
    mechanicId: input.mechanicId,
    mechanicName: input.mechanicName,
    tenders: input.tenders,
    discountType: input.discountType,
    paymentMethod: input.paymentMethod,
    amountReceived: input.amountReceived,
    changeGiven: input.changeGiven,
    status: SaleStatus.completed,
    cashierId: actor.id,
    cashierName,
    draftId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
  };
}

import type { Sale } from '@/domain/entities/Sale';
import type { User } from '@/domain/entities/User';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { FeeLine } from '@/domain/entities/FeeLine';
import type { CartLine } from '@/domain/sales/cart';
import type { DiscountType } from '@/domain/enums/DiscountType';
import type { PaymentMethod } from '@/domain/enums/PaymentMethod';
import { SaleStatus } from '@/domain/enums/SaleStatus';

export interface CheckoutInput {
  /** Cart-minted idempotency token — becomes the sale doc id so a retry
   *  can never record the sale twice. */
  checkoutId: string;
  lines: CartLine[];
  discountType: DiscountType;
  paymentMethod: PaymentMethod;
  tenders: Partial<Record<PaymentMethod, number>>;
  amountReceived: number;
  changeGiven: number;
  laborLines: LaborLine[];
  // Carried from a resumed job order (a plain non-job order web sale passes []) — see
  // web_admin/src/presentation/stores/cartStore.ts `feeLines`.
  feeLines: FeeLine[];
  mechanicId: string | null;
  mechanicName: string | null;
  /** Carried from the job order this checkout bills out; null for a walk-in. */
  motorcycleModel: string | null;
  jobOrderId: string | null;
  /** Pre-minted JO number for a direct service sale (mechanic/motorcycle,
   *  no source ticket) — the sale transaction records a billed job order
   *  under it. Null = no auto ticket. */
  autoJobOrderName: string | null;
  // Cart notes (typed at JO save or restored on resume) ride onto the sale —
  // mobile's toSale() does the same.
  notes: string | null;
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
    feeLines: input.feeLines,
    mechanicId: input.mechanicId,
    mechanicName: input.mechanicName,
    motorcycleModel: input.motorcycleModel,
    tenders: input.tenders,
    discountType: input.discountType,
    paymentMethod: input.paymentMethod,
    amountReceived: input.amountReceived,
    changeGiven: input.changeGiven,
    status: SaleStatus.completed,
    cashierId: actor.id,
    cashierName,
    jobOrderId: input.jobOrderId,
    notes: input.notes,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
  };
}

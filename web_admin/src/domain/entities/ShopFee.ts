// Mirror of lib/domain/entities/shop_fee_entity.dart — the admin-managed fee
// catalog (managed in mobile Settings; web only READS it for the POS picker).
// Inactive fees drop off the picker but stay valid on historical records via
// the snapshotted name/amount on the job order/sale.
export interface ShopFee {
  id: string;
  name: string;
  /** Pre-filled when the fee is picked; null = cashier enters the amount. */
  defaultAmount: number | null;
  isActive: boolean;
}

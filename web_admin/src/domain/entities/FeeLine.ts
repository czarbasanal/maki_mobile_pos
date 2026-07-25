// Mirror of lib/domain/entities/fee_line_entity.dart. Stored INLINE on the
// sale document's `feeLines` array. Shop fees belong to the SHOP (management),
// are never discounted, and have zero cost — a third revenue track beside
// parts and labor.
export interface FeeLine {
  id: string;
  name: string;
  amount: number;
}

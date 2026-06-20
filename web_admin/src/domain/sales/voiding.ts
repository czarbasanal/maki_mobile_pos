import type { Sale } from '@/domain/entities';
import { saleIsVoided } from '@/domain/entities';
import { SaleStatus } from '@/domain/enums/SaleStatus';

/** A sale can be voided only if it is a completed sale that isn't already voided. */
export function canVoidSale(sale: Sale): boolean {
  return !saleIsVoided(sale) && sale.status === SaleStatus.completed;
}

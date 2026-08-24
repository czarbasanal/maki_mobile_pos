import type { Sale } from '@/domain/entities';
import { saleIsVoided } from '@/domain/entities';
import { SaleStatus } from '@/domain/enums/SaleStatus';

/** A sale can be voided only if it is a completed sale that isn't already voided. */
export function canVoidSale(sale: Sale): boolean {
  return !saleIsVoided(sale) && sale.status === SaleStatus.completed;
}

// Compact receipt line for a void request — mobile's RequestVoidSaleUseCase
// rule: '2× Spark Plug, 1× Oil' truncated at 80 chars; labor-only sales say
// 'Service / labor'; nothing sellable -> null (field omitted from the doc).
export function voidRequestItemsSummary(sale: Sale): string | null {
  if (sale.items.length === 0) {
    return sale.laborLines.length > 0 ? 'Service / labor' : null;
  }
  const summary = sale.items.map((i) => `${i.quantity}× ${i.name}`).join(', ');
  return summary.length > 80 ? `${summary.substring(0, 79)}…` : summary;
}

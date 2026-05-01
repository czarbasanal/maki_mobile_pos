// Mirror of lib/core/enums/sale_status.dart.
export const SaleStatus = {
  completed: 'completed',
  voided: 'voided',
  draft: 'draft',
} as const;

export type SaleStatus = (typeof SaleStatus)[keyof typeof SaleStatus];

export const saleStatusDisplayName: Record<SaleStatus, string> = {
  completed: 'Completed',
  voided: 'Voided',
  draft: 'Draft',
};

export function saleStatusFromString(value: string | null | undefined): SaleStatus {
  if (value === SaleStatus.voided || value === SaleStatus.draft) return value;
  return SaleStatus.completed;
}

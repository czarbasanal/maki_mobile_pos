// Mirror of lib/core/enums/discount_type.dart.
export const DiscountType = {
  amount: 'amount',
  percentage: 'percentage',
} as const;

export type DiscountType = (typeof DiscountType)[keyof typeof DiscountType];

export const discountTypeDisplayName: Record<DiscountType, string> = {
  amount: 'Amount',
  percentage: 'Percentage',
};

export function discountTypeFromString(value: string | null | undefined): DiscountType {
  return value === DiscountType.percentage ? DiscountType.percentage : DiscountType.amount;
}

// Mirror of lib/core/enums/payment_method.dart.
export const PaymentMethod = {
  cash: 'cash',
  gcash: 'gcash',
} as const;

export type PaymentMethod = (typeof PaymentMethod)[keyof typeof PaymentMethod];

export const paymentMethodDisplayName: Record<PaymentMethod, string> = {
  cash: 'Cash',
  gcash: 'GCash',
};

export function paymentMethodFromString(value: string | null | undefined): PaymentMethod {
  return value === PaymentMethod.gcash ? PaymentMethod.gcash : PaymentMethod.cash;
}

export function paymentMethodHasFees(method: PaymentMethod): boolean {
  return method === PaymentMethod.gcash;
}

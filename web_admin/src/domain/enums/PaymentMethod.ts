// Mirror of lib/core/enums/payment_method.dart.
export const PaymentMethod = {
  cash: 'cash',
  gcash: 'gcash',
  maya: 'maya',
  salmon: 'salmon',
  mixed: 'mixed',
} as const;

export type PaymentMethod = (typeof PaymentMethod)[keyof typeof PaymentMethod];

export const paymentMethodDisplayName: Record<PaymentMethod, string> = {
  cash: 'Cash',
  gcash: 'GCash',
  maya: 'Maya',
  salmon: 'Salmon',
  mixed: 'Mixed',
};

const _knownMethods = new Set<string>(Object.values(PaymentMethod));

export function paymentMethodFromString(
  value: string | null | undefined,
): PaymentMethod {
  return value != null && _knownMethods.has(value)
    ? (value as PaymentMethod)
    : PaymentMethod.cash;
}

export function paymentMethodHasFees(method: PaymentMethod): boolean {
  return method === PaymentMethod.gcash || method === PaymentMethod.maya;
}

/// Real tender buckets that can physically hold money. `mixed` is a label for
/// a split sale, never a bucket — its split lands in the real buckets via the
/// sale's `tenders` map.
export const realTenderMethods: PaymentMethod[] = [
  PaymentMethod.cash,
  PaymentMethod.gcash,
  PaymentMethod.maya,
  PaymentMethod.salmon,
];

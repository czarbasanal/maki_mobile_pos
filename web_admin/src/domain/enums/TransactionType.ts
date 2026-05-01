// Mirror of lib/core/enums/transaction_type.dart.
export const TransactionType = {
  cash: 'cash',
  terms30d: 'terms_30d',
  terms45d: 'terms_45d',
  terms60d: 'terms_60d',
  terms90d: 'terms_90d',
  notApplicable: 'na',
} as const;

export type TransactionType = (typeof TransactionType)[keyof typeof TransactionType];

export const transactionTypeDisplayName: Record<TransactionType, string> = {
  cash: 'Cash',
  terms_30d: '30 Days',
  terms_45d: '45 Days',
  terms_60d: '60 Days',
  terms_90d: '90 Days',
  na: 'N/A',
};

export function transactionTypeFromString(value: string | null | undefined): TransactionType {
  switch (value) {
    case TransactionType.cash:
    case TransactionType.terms30d:
    case TransactionType.terms45d:
    case TransactionType.terms60d:
    case TransactionType.terms90d:
      return value;
    default:
      return TransactionType.notApplicable;
  }
}

export function daysUntilDue(t: TransactionType): number | null {
  switch (t) {
    case TransactionType.cash:
      return 0;
    case TransactionType.terms30d:
      return 30;
    case TransactionType.terms45d:
      return 45;
    case TransactionType.terms60d:
      return 60;
    case TransactionType.terms90d:
      return 90;
    case TransactionType.notApplicable:
      return null;
  }
}

import { FirestoreCollections } from '../../infrastructure/firebase/collections';

export const CategoryKind = {
  product: 'product',
  unit: 'unit',
  expense: 'expense',
  voidReason: 'voidReason',
} as const;
export type CategoryKind = (typeof CategoryKind)[keyof typeof CategoryKind];

/** The Firestore collection backing a given list kind. */
export function collectionForKind(kind: CategoryKind): string {
  switch (kind) {
    case CategoryKind.product:
      return FirestoreCollections.productCategories;
    case CategoryKind.unit:
      return FirestoreCollections.units;
    case CategoryKind.expense:
      return FirestoreCollections.expenseCategories;
    case CategoryKind.voidReason:
      return FirestoreCollections.voidReasons;
  }
}

/** The human label for a list kind. */
export function labelForKind(kind: CategoryKind): string {
  switch (kind) {
    case CategoryKind.product:
      return 'Product categories';
    case CategoryKind.unit:
      return 'Units';
    case CategoryKind.expense:
      return 'Expense categories';
    case CategoryKind.voidReason:
      return 'Void reasons';
  }
}

import { describe, expect, it } from 'vitest';
import { CategoryKind, collectionForKind, labelForKind } from './categoryKind';

describe('collectionForKind', () => {
  it('maps each kind to its Firestore collection', () => {
    expect(collectionForKind(CategoryKind.product)).toBe('product_categories');
    expect(collectionForKind(CategoryKind.unit)).toBe('units');
    expect(collectionForKind(CategoryKind.expense)).toBe('expense_categories');
    expect(collectionForKind(CategoryKind.voidReason)).toBe('void_reasons');
  });
});

describe('labelForKind', () => {
  it('returns the UI labels', () => {
    expect(labelForKind(CategoryKind.product)).toBe('Product categories');
    expect(labelForKind(CategoryKind.unit)).toBe('Units');
    expect(labelForKind(CategoryKind.expense)).toBe('Expense categories');
    expect(labelForKind(CategoryKind.voidReason)).toBe('Void reasons');
  });
});

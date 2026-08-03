import { describe, expect, it } from 'vitest';
import { saleItemDisplayName, saleItemOptionSetsCaption } from './SaleItem';
import type { SaleItem } from './SaleItem';

// Extracted so every render site (Receipt, SaleDetailPage, OrderSummary,
// DaySalesPage) builds the same option-label / sets-caption strings from
// one place instead of hand-copying the ternary/ guard at each site.
function item(overrides: Partial<SaleItem> = {}): SaleItem {
  return {
    id: 'i1',
    productId: 'p1',
    sku: 'ABC-1',
    name: 'Pulley Ball',
    unitPrice: 120,
    unitCost: 60,
    quantity: 2,
    discountValue: 0,
    unit: 'pcs',
    optionId: null,
    optionLabel: null,
    optionPieces: null,
    optionPrice: null,
    ...overrides,
  };
}

const optionItem = (quantity: number) =>
  item({
    unitPrice: 110,
    quantity,
    optionId: 'o2',
    optionLabel: 'By 3',
    optionPieces: 3,
    optionPrice: 330,
  });

describe('saleItemDisplayName', () => {
  it('is the bare name with no option', () => {
    expect(saleItemDisplayName(item())).toBe('Pulley Ball');
  });

  it('appends the option label for exactly one set', () => {
    expect(saleItemDisplayName(optionItem(3))).toBe('Pulley Ball · By 3');
  });

  it('appends the option label for more than one set', () => {
    expect(saleItemDisplayName(optionItem(6))).toBe('Pulley Ball · By 3');
  });
});

describe('saleItemOptionSetsCaption', () => {
  it('is null with no option', () => {
    expect(saleItemOptionSetsCaption(item())).toBeNull();
  });

  it('is null for exactly one set', () => {
    expect(saleItemOptionSetsCaption(optionItem(3))).toBeNull();
  });

  it('shows sets and total pieces for more than one set', () => {
    expect(saleItemOptionSetsCaption(optionItem(6))).toBe('By 3 × 2 (6 pcs)');
  });
});

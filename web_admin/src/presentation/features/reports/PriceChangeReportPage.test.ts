// Pinning test for the price-change CSV export's leading-zero-safe SKU
// display (an 8-digit auto-SKU must render as 'XXXX-XXXX' so Excel/Sheets
// doesn't eat the leading zeros — see displaySku).
import { describe, expect, it } from 'vitest';
import type { PriceChangeRow } from '@/domain/products/priceChangeReport';
import { priceChangeCsvRow } from './PriceChangeReportPage';

function row(overrides: Partial<PriceChangeRow['entry']> = {}): PriceChangeRow {
  return {
    entry: {
      id: 'e1',
      productId: 'p1',
      price: 150,
      cost: 100,
      changedAt: new Date('2026-07-01T00:00:00Z'),
      changedBy: 'user-1',
      reason: 'Restock',
      ...overrides,
    },
    priceDelta: 10,
    costDelta: 5,
    hasPrior: true,
  };
}

describe('priceChangeCsvRow', () => {
  it('formats an 8-digit auto-SKU as XXXX-XXXX', () => {
    const csvRow = priceChangeCsvRow(row(), { name: 'Oil Filter', sku: '00070153' });
    expect(csvRow[2]).toBe('0007-0153');
  });

  it('leaves a non-auto SKU unchanged', () => {
    const csvRow = priceChangeCsvRow(row(), { name: 'Oil Filter', sku: 'BRAKE-99' });
    expect(csvRow[2]).toBe('BRAKE-99');
  });

  it('passes an empty string through unchanged when the product is unknown', () => {
    const csvRow = priceChangeCsvRow(row(), undefined);
    expect(csvRow[2]).toBe('');
  });

  // Option lives at index 3, right after SKU (index 2) — the assertions above
  // pin the SKU column and must keep passing unchanged; Option was added
  // after it, not before, so it never shifts them.
  describe('Option column', () => {
    it("puts the option's label at index 3, adjacent to the SKU column", () => {
      const optionRow = row({ optionId: 'o2', optionLabel: 'By 3', optionPieces: 3 });
      const csvRow = priceChangeCsvRow(optionRow, { name: 'Pulley Ball', sku: 'ABC-1' });
      expect(csvRow[3]).toBe('By 3');
    });

    it('leaves the Option cell an empty string for a base row — not "Base" or a dash', () => {
      const csvRow = priceChangeCsvRow(row(), { name: 'Pulley Ball', sku: 'ABC-1' });
      expect(csvRow[3]).toBe('');
    });

    it('does not disturb the SKU pinning column when Option is present', () => {
      const optionRow = row({ optionId: 'o2', optionLabel: 'By 3', optionPieces: 3 });
      const csvRow = priceChangeCsvRow(optionRow, { name: 'Oil Filter', sku: '00070153' });
      expect(csvRow[2]).toBe('0007-0153');
    });
  });
});

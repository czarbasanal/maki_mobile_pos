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
});

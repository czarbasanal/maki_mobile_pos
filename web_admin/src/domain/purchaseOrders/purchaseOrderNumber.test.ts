import { describe, expect, it } from 'vitest';
import {
  formatPurchaseOrderNumber,
  purchaseOrderCounterKey,
} from './purchaseOrderNumber';

describe('purchase order numbering', () => {
  const phOffset = 480;

  it('matches the format mobile writes', () => {
    expect(
      formatPurchaseOrderNumber(new Date('2026-08-31T02:00:00Z'), 1, phOffset),
    ).toBe('PO-20260831-001');
  });

  it('pads to three digits and keeps going past them', () => {
    const d = new Date('2026-08-31T02:00:00Z');
    expect(formatPurchaseOrderNumber(d, 7, phOffset)).toBe('PO-20260831-007');
    expect(formatPurchaseOrderNumber(d, 142, phOffset)).toBe('PO-20260831-142');
    expect(formatPurchaseOrderNumber(d, 1000, phOffset)).toBe('PO-20260831-1000');
  });

  it("keys on the SHOP day, not the browser's", () => {
    // 17:00Z is 01:00 the NEXT day in the shop. A browser-local key would
    // restart the series mid-afternoon, or continue yesterday's into today.
    expect(purchaseOrderCounterKey(new Date('2026-08-31T17:00:00Z'), phOffset))
        .toBe('20260901');
    expect(purchaseOrderCounterKey(new Date('2026-08-31T02:00:00Z'), phOffset))
        .toBe('20260831');
  });
});

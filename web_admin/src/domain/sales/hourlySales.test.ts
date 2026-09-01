import { describe, expect, it } from 'vitest';
import { bucketSalesByHour, formatHourLabel, peakHour, DEFAULT_OPEN_HOUR, DEFAULT_CLOSE_HOUR } from './hourlySales';
import { DiscountType, SaleStatus } from '../enums';
import type { Sale } from '../entities';
import { instantOf } from '../time/shopTime';

// Minimal sale: one ₱100 item, created at the given shop-wall hour.
function fakeSale(hour: number, overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's', saleNumber: 'SALE-1', laborLines: [], feeLines: [], mechanicId: null,
    mechanicName: null, motorcycleModel: null, tenders: {}, discountType: DiscountType.amount,
    paymentMethod: 'cash', amountReceived: 100, changeGiven: 0, status: SaleStatus.completed,
    cashierId: 'c', cashierName: 'C', updatedAt: null, jobOrderId: null, notes: null,
    voidedAt: null, voidedBy: null, voidedByName: null, voidReason: null,
    createdAt: instantOf(new Date(Date.UTC(2026, 7, 31, hour, 15))),
    items: [{
      id: 'i', productId: 'p', sku: 'SKU-1', name: 'Part', quantity: 1, unitPrice: 100,
      unitCost: 60, discountValue: 0, unit: 'pcs', optionId: null, optionLabel: null,
      optionPieces: null, optionPrice: null,
    } as Sale['items'][number]],
    ...overrides,
  } as Sale;
}

describe('bucketSalesByHour', () => {
  it('buckets counts and gross by shop-wall hour', () => {
    const buckets = bucketSalesByHour([fakeSale(9), fakeSale(9), fakeSale(14)]);
    const nine = buckets.find((b) => b.hour === 9)!;
    expect(nine.count).toBe(2);
    expect(nine.gross).toBe(200);
    expect(buckets.find((b) => b.hour === 14)!.count).toBe(1);
  });

  it('excludes voided sales', () => {
    const voided = fakeSale(9, { status: SaleStatus.voided, voidedAt: new Date() });
    const nine = bucketSalesByHour([voided]).find((b) => b.hour === 9);
    expect(nine?.count ?? 0).toBe(0);
  });

  it('always spans at least the default open hours, extended by outliers', () => {
    const buckets = bucketSalesByHour([fakeSale(22)]);
    expect(buckets[0].hour).toBe(DEFAULT_OPEN_HOUR);
    expect(buckets[buckets.length - 1].hour).toBe(22);
    expect(buckets.length).toBe(22 - DEFAULT_OPEN_HOUR + 1);
  });

  it('spans exactly the default window when there are no sales', () => {
    const buckets = bucketSalesByHour([]);
    expect(buckets[0].hour).toBe(DEFAULT_OPEN_HOUR);
    expect(buckets[buckets.length - 1].hour).toBe(DEFAULT_CLOSE_HOUR);
  });
});

describe('peakHour', () => {
  it('is the argmax-count hour', () => {
    expect(peakHour(bucketSalesByHour([fakeSale(9), fakeSale(12), fakeSale(12)]))).toBe(12);
  });
  it('is null with no sales', () => {
    expect(peakHour(bucketSalesByHour([]))).toBeNull();
  });
});

describe('formatHourLabel', () => {
  it('formats 12-hour labels', () => {
    expect(formatHourLabel(0)).toBe('12 AM');
    expect(formatHourLabel(8)).toBe('8 AM');
    expect(formatHourLabel(12)).toBe('12 PM');
    expect(formatHourLabel(13)).toBe('1 PM');
    expect(formatHourLabel(12, true)).toBe('12:00 PM');
  });
});

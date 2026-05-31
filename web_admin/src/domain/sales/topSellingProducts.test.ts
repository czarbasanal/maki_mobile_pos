import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import { type Sale } from '../entities';
import { topSellingProducts } from './topSellingProducts';

function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's',
    saleNumber: 'S',
    items: [],
    laborLines: [],
    mechanicId: null,
    mechanicName: null,
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 0,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date('2026-05-13T10:00:00Z'),
    updatedAt: null,
    draftId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...overrides,
  };
}

function item(productId: string, name: string, qty: number, price: number, cost: number) {
  return {
    id: `${productId}-${qty}`,
    productId,
    sku: productId.toUpperCase(),
    name,
    unitPrice: price,
    unitCost: cost,
    quantity: qty,
    discountValue: 0,
    unit: 'pcs',
  };
}

describe('topSellingProducts', () => {
  it('groups by product, sums qty/revenue/cost, sorts by revenue desc', () => {
    const sales = [
      sale({ items: [item('p1', 'Spark Plug', 2, 100, 60), item('p2', 'Oil', 1, 300, 200)] }),
      sale({ items: [item('p1', 'Spark Plug', 3, 100, 60)] }),
    ];
    const top = topSellingProducts(sales);
    expect(top).toHaveLength(2);
    // p1: qty 5, revenue 500, cost 300, profit 200 (revenue 500 > p2 300)
    expect(top[0]).toMatchObject({
      productId: 'p1',
      name: 'Spark Plug',
      quantitySold: 5,
      totalRevenue: 500,
      totalCost: 300,
      totalProfit: 200,
    });
    expect(top[1].productId).toBe('p2');
  });

  it('excludes voided sales', () => {
    const sales = [
      sale({ items: [item('p1', 'A', 1, 100, 60)] }),
      sale({ status: SaleStatus.voided, items: [item('p1', 'A', 9, 100, 60)] }),
    ];
    expect(topSellingProducts(sales)[0].quantitySold).toBe(1);
  });

  it('respects the limit', () => {
    const sales = [
      sale({
        items: [
          item('p1', 'A', 1, 500, 1),
          item('p2', 'B', 1, 400, 1),
          item('p3', 'C', 1, 300, 1),
        ],
      }),
    ];
    expect(topSellingProducts(sales, 2).map((p) => p.productId)).toEqual(['p1', 'p2']);
  });

  it('item revenue is net of the item discount', () => {
    const s = sale({
      discountType: DiscountType.amount,
      items: [{ ...item('p1', 'A', 2, 100, 60), discountValue: 50 }], // 200 gross - 50 = 150
    });
    expect(topSellingProducts([s])[0].totalRevenue).toBe(150);
  });
});

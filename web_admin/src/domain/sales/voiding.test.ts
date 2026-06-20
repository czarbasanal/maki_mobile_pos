import { describe, expect, it } from 'vitest';
import { canVoidSale } from './voiding';
import { SaleStatus } from '@/domain/enums/SaleStatus';
import type { Sale } from '@/domain/entities';

const sale = (over: Partial<Sale> = {}): Sale =>
  ({
    id: 's1',
    status: SaleStatus.completed,
    voidedAt: null,
    items: [],
    laborLines: [],
    ...over,
  }) as Sale;

describe('canVoidSale', () => {
  it('is true for a completed, not-voided sale', () => {
    expect(canVoidSale(sale())).toBe(true);
  });
  it('is false when already voided', () => {
    expect(canVoidSale(sale({ status: SaleStatus.voided, voidedAt: new Date('2026-02-01') }))).toBe(false);
  });
  it('is false when the status is not completed', () => {
    expect(canVoidSale(sale({ status: SaleStatus.voided }))).toBe(false);
  });
});

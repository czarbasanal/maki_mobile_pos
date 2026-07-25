import { describe, expect, it } from 'vitest';
import { buildSaleInput, type CheckoutInput } from './buildSaleInput';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import { DiscountType } from '@/domain/enums/DiscountType';
import { SaleStatus } from '@/domain/enums/SaleStatus';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities/User';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { FeeLine } from '@/domain/entities/FeeLine';

const actor = (over: Partial<User> = {}): User => ({
  id: 'u1',
  email: 'cashier@shop.test',
  displayName: 'Cashier One',
  role: UserRole.cashier,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
  ...over,
});

const input = (over: Partial<CheckoutInput> = {}): CheckoutInput => ({
  lines: [],
  discountType: DiscountType.amount,
  paymentMethod: PaymentMethod.cash,
  tenders: { [PaymentMethod.cash]: 100 },
  amountReceived: 100,
  changeGiven: 0,
  laborLines: [],
  feeLines: [],
  mechanicId: null,
  mechanicName: null,
  draftId: null,
  ...over,
});

describe('buildSaleInput', () => {
  it('carries the payment method + tenders through verbatim', () => {
    const s = buildSaleInput(
      input({ paymentMethod: PaymentMethod.mixed, tenders: { cash: 300, gcash: 700 } }),
      actor(),
    );
    expect(s.paymentMethod).toBe(PaymentMethod.mixed);
    expect(s.tenders).toEqual({ cash: 300, gcash: 700 });
  });
  it('stamps the actor as cashier and marks the sale completed', () => {
    const s = buildSaleInput(input(), actor({ id: 'u9', displayName: 'Jo' }));
    expect(s.cashierId).toBe('u9');
    expect(s.cashierName).toBe('Jo');
    expect(s.status).toBe(SaleStatus.completed);
    expect(s.saleNumber).toBe('');
  });
  it('falls back to email when displayName is blank', () => {
    const s = buildSaleInput(input(), actor({ displayName: '   ', email: 'x@y.z' }));
    expect(s.cashierName).toBe('x@y.z');
  });
  it('carries labor lines + mechanic through verbatim', () => {
    const labor: LaborLine[] = [{ id: 'l1', description: 'Tune-up', fee: 500 }];
    const s = buildSaleInput(
      input({ laborLines: labor, mechanicId: 'm1', mechanicName: 'Juan' }),
      actor(),
    );
    expect(s.laborLines).toEqual(labor);
    expect(s.mechanicId).toBe('m1');
    expect(s.mechanicName).toBe('Juan');
  });
  it('carries draftId onto the sale (sale originated from a draft)', () => {
    const s = buildSaleInput(input({ draftId: 'd1' }), actor());
    expect(s.draftId).toBe('d1');
  });
  it('carries fee lines through verbatim (mirrors labor)', () => {
    const fees: FeeLine[] = [{ id: 'f1', name: 'Convenience fee', amount: 50 }];
    const s = buildSaleInput(input({ feeLines: fees }), actor());
    expect(s.feeLines).toEqual(fees);
  });
  it('defaults to no fees for a plain non-draft sale', () => {
    const s = buildSaleInput(input(), actor());
    expect(s.feeLines).toEqual([]);
  });
  it('a draft-with-fees survives bill-out: the built sale input carries the draft-sourced fee lines', () => {
    // Simulates the resumed-draft → checkout path: CheckoutPage sources
    // feeLines from the cart store (hydrated by loadDraft(draft)), not a
    // hardcoded []. This is the carried money-correctness finding.
    const draftFeeLines: FeeLine[] = [{ id: 'f1', name: 'Shop fee', amount: 75 }];
    const s = buildSaleInput(
      input({ draftId: 'd1', feeLines: draftFeeLines }),
      actor(),
    );
    expect(s.draftId).toBe('d1');
    expect(s.feeLines).toEqual(draftFeeLines);
  });
});

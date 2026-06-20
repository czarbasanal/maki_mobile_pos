import { describe, expect, it } from 'vitest';
import {
  amountReceivedFor,
  buildTenders,
  changeGivenFor,
  emptyPaymentDraft,
  paymentError,
  paymentLabel,
  type PaymentDraft,
} from './payment';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';

const draft = (over: Partial<PaymentDraft> = {}): PaymentDraft => ({
  ...emptyPaymentDraft,
  ...over,
});

describe('paymentLabel', () => {
  it('maps each mode to its PaymentMethod label', () => {
    expect(paymentLabel('cash')).toBe(PaymentMethod.cash);
    expect(paymentLabel('gcash')).toBe(PaymentMethod.gcash);
    expect(paymentLabel('maya')).toBe(PaymentMethod.maya);
    expect(paymentLabel('mixed')).toBe(PaymentMethod.mixed);
    expect(paymentLabel('salmon')).toBe(PaymentMethod.salmon);
  });
});

describe('buildTenders', () => {
  it('cash puts the whole total in the cash bucket', () => {
    expect(buildTenders(draft({ mode: 'cash' }), 250)).toEqual({ cash: 250 });
  });
  it('gcash / maya put the whole total in their bucket', () => {
    expect(buildTenders(draft({ mode: 'gcash' }), 250)).toEqual({ gcash: 250 });
    expect(buildTenders(draft({ mode: 'maya' }), 250)).toEqual({ maya: 250 });
  });
  it('single-method keeps the RAW total (sub-cent) so it equals netAmount exactly', () => {
    // grandTotal can carry sub-cent fractions from an un-rounded % discount;
    // rounding the tender here would break Σ byPaymentMethod == netAmount.
    expect(buildTenders(draft({ mode: 'cash' }), 8.4915)).toEqual({ cash: 8.4915 });
    expect(buildTenders(draft({ mode: 'gcash' }), 8.4915)).toEqual({ gcash: 8.4915 });
  });
  it('mixed splits cash + chosen digital; cash = remainder', () => {
    expect(
      buildTenders(draft({ mode: 'mixed', digitalMethod: 'gcash', splitAmount: 700 }), 1000),
    ).toEqual({ cash: 300, gcash: 700 });
  });
  it('mixed rounds the cash remainder to cents', () => {
    expect(
      buildTenders(draft({ mode: 'mixed', digitalMethod: 'maya', splitAmount: 33.33 }), 100),
    ).toEqual({ cash: 66.67, maya: 33.33 });
  });
  it('salmon splits downpayment (any method) + salmon balance', () => {
    expect(
      buildTenders(draft({ mode: 'salmon', dpMethod: 'cash', splitAmount: 500 }), 2000),
    ).toEqual({ cash: 500, salmon: 1500 });
    expect(
      buildTenders(draft({ mode: 'salmon', dpMethod: 'gcash', splitAmount: 500 }), 2000),
    ).toEqual({ gcash: 500, salmon: 1500 });
  });
});

describe('amountReceivedFor', () => {
  it('cash returns the cash handed over', () => {
    expect(amountReceivedFor(draft({ mode: 'cash', cashReceived: 300 }), 250)).toBe(300);
  });
  it('gcash / maya / mixed return the full (raw) total', () => {
    expect(amountReceivedFor(draft({ mode: 'gcash' }), 250)).toBe(250);
    expect(amountReceivedFor(draft({ mode: 'mixed', splitAmount: 100 }), 250)).toBe(250);
    expect(amountReceivedFor(draft({ mode: 'gcash' }), 8.4915)).toBe(8.4915);
  });
  it('salmon returns only the downpayment collected today', () => {
    expect(amountReceivedFor(draft({ mode: 'salmon', splitAmount: 500 }), 2000)).toBe(500);
  });
});

describe('changeGivenFor', () => {
  it('cash returns received minus total, floored at 0', () => {
    expect(changeGivenFor(draft({ mode: 'cash', cashReceived: 300 }), 250)).toBe(50);
    expect(changeGivenFor(draft({ mode: 'cash', cashReceived: 250 }), 250)).toBe(0);
  });
  it('is 0 for every non-cash mode', () => {
    expect(changeGivenFor(draft({ mode: 'gcash' }), 250)).toBe(0);
    expect(changeGivenFor(draft({ mode: 'mixed', splitAmount: 100 }), 250)).toBe(0);
    expect(changeGivenFor(draft({ mode: 'salmon', splitAmount: 100 }), 250)).toBe(0);
  });
});

describe('paymentError', () => {
  it('cash requires received >= total', () => {
    expect(paymentError(draft({ mode: 'cash', cashReceived: 240 }), 250)).toBe(
      'Cash received is less than the total',
    );
    expect(paymentError(draft({ mode: 'cash', cashReceived: 250 }), 250)).toBeNull();
    expect(paymentError(draft({ mode: 'cash', cashReceived: 300 }), 250)).toBeNull();
  });
  it('gcash / maya are always valid', () => {
    expect(paymentError(draft({ mode: 'gcash' }), 250)).toBeNull();
    expect(paymentError(draft({ mode: 'maya' }), 250)).toBeNull();
  });
  it('mixed requires 0 < digital < total', () => {
    expect(paymentError(draft({ mode: 'mixed', splitAmount: 0 }), 250)).toBe(
      'Digital amount must be between ₱0 and the total',
    );
    expect(paymentError(draft({ mode: 'mixed', splitAmount: 250 }), 250)).toBe(
      'Digital amount must be between ₱0 and the total',
    );
    expect(paymentError(draft({ mode: 'mixed', splitAmount: 100 }), 250)).toBeNull();
  });
  it('salmon requires 0 < downpayment < total', () => {
    expect(paymentError(draft({ mode: 'salmon', splitAmount: 0 }), 250)).toBe(
      'Downpayment must be between ₱0 and the total',
    );
    expect(paymentError(draft({ mode: 'salmon', splitAmount: 250 }), 250)).toBe(
      'Downpayment must be between ₱0 and the total',
    );
    expect(paymentError(draft({ mode: 'salmon', splitAmount: 100 }), 250)).toBeNull();
  });
});

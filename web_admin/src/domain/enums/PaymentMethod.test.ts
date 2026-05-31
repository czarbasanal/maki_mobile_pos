import { describe, expect, it } from 'vitest';
import {
  PaymentMethod,
  paymentMethodFromString,
  realTenderMethods,
} from './PaymentMethod';

describe('PaymentMethod', () => {
  it('maps every known Firestore value, defaulting unknown to cash', () => {
    expect(paymentMethodFromString('cash')).toBe(PaymentMethod.cash);
    expect(paymentMethodFromString('gcash')).toBe(PaymentMethod.gcash);
    expect(paymentMethodFromString('maya')).toBe(PaymentMethod.maya);
    expect(paymentMethodFromString('salmon')).toBe(PaymentMethod.salmon);
    expect(paymentMethodFromString('mixed')).toBe(PaymentMethod.mixed);
    expect(paymentMethodFromString('bogus')).toBe(PaymentMethod.cash);
    expect(paymentMethodFromString(null)).toBe(PaymentMethod.cash);
  });

  it('realTenderMethods are the money-holding buckets and exclude mixed', () => {
    expect(realTenderMethods).toEqual([
      PaymentMethod.cash,
      PaymentMethod.gcash,
      PaymentMethod.maya,
      PaymentMethod.salmon,
    ]);
    expect(realTenderMethods).not.toContain(PaymentMethod.mixed);
  });
});

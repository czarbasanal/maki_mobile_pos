import { describe, expect, it } from 'vitest';
import { CHARGE_ITEM_FEE_NAME, chargeableFeeLines, feeLineDisplayLabel } from './FeeLine';

describe('feeLineDisplayLabel', () => {
  it('is just the name for ordinary fees', () => {
    expect(feeLineDisplayLabel({ id: 'f', name: 'Tire changer', amount: 50, description: null })).toBe(
      'Tire changer',
    );
  });
  it('appends the description for Charge Item fees', () => {
    expect(
      feeLineDisplayLabel({
        id: 'f',
        name: CHARGE_ITEM_FEE_NAME,
        amount: 120,
        description: 'Brake fluid from outside',
      }),
    ).toBe('Charge Item — Brake fluid from outside');
  });
  it('falls back to the name when the description is blank', () => {
    expect(
      feeLineDisplayLabel({ id: 'f', name: 'Charge Item', amount: 120, description: '  ' }),
    ).toBe('Charge Item');
  });
});

describe('chargeableFeeLines (inline-entry write filter)', () => {
  it('keeps only complete rows: fee picked, amount > 0, Charge Item described', () => {
    const rows = [
      { id: 'a', name: 'Air', amount: 10, description: null },
      { id: 'b', name: '', amount: 50, description: null }, // no fee picked
      { id: 'c', name: 'Tire changer', amount: 0, description: null }, // no amount
      { id: 'd', name: 'Charge Item', amount: 120, description: ' ' }, // undescribed
      { id: 'e', name: 'Charge Item', amount: 120, description: 'Outside part' },
    ];
    expect(chargeableFeeLines(rows).map((l) => l.id)).toEqual(['a', 'e']);
  });
});

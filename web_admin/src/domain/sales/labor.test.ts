import { describe, expect, it } from 'vitest';
import { cartLaborSubtotal, describedLaborLines, laborValidationError } from './labor';
import type { LaborLine } from '@/domain/entities/LaborLine';

const line = (over: Partial<LaborLine> = {}): LaborLine => ({
  id: 'l1',
  description: 'Tune-up',
  fee: 500,
  ...over,
});

describe('describedLaborLines', () => {
  it('keeps only lines with a non-blank description (fee may be 0)', () => {
    const lines = [
      line({ id: 'a', description: 'Tune-up', fee: 500 }),
      line({ id: 'b', description: '   ', fee: 300 }), // blank → dropped
      line({ id: 'c', description: 'Courtesy check', fee: 0 }), // kept, fee 0 ok
      line({ id: 'd', description: '', fee: 0 }), // blank → dropped
    ];
    expect(describedLaborLines(lines).map((l) => l.id)).toEqual(['a', 'c']);
  });
});

describe('cartLaborSubtotal', () => {
  it('sums fees of described lines only', () => {
    const lines = [
      line({ id: 'a', description: 'Tune-up', fee: 500 }),
      line({ id: 'b', description: '   ', fee: 300 }), // blank desc → excluded
      line({ id: 'c', description: 'Brake bleed', fee: 250 }),
    ];
    expect(cartLaborSubtotal(lines)).toBe(750);
  });
  it('is 0 for an empty list', () => {
    expect(cartLaborSubtotal([])).toBe(0);
  });
});

describe('laborValidationError (mobile-parity checkout gate)', () => {
  const line = (description: string, fee: number) => ({ id: 'l1', description, fee });

  it('is null with no labor lines, regardless of mechanic', () => {
    expect(laborValidationError([], null)).toBeNull();
  });

  it('requires a description on every line', () => {
    expect(laborValidationError([line('', 100)], 'm1')).toBe(
      'Each labor line needs a description.',
    );
  });

  it('requires every fee to be greater than zero', () => {
    expect(laborValidationError([line('Change oil', 0)], 'm1')).toBe(
      'Each labor fee must be greater than ₱0.',
    );
  });

  it('requires a mechanic once labor is charged', () => {
    expect(laborValidationError([line('Change oil', 100)], null)).toBe(
      'Assign a mechanic before saving labor.',
    );
  });

  it('passes a complete labor setup', () => {
    expect(laborValidationError([line('Change oil', 100)], 'm1')).toBeNull();
  });
});

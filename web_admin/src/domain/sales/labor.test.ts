import { describe, expect, it } from 'vitest';
import { cartLaborSubtotal, describedLaborLines } from './labor';
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

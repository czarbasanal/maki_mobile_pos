import { describe, expect, it } from 'vitest';
import { feeLinesToMaps, parseFeeLines } from './feeLines';

describe('feeLines converter', () => {
  it('round-trips the description (Charge Item money must not lose its note)', () => {
    const lines = [
      { id: 'f1', name: 'Charge Item', amount: 120, description: 'Outside part' },
      { id: 'f2', name: 'Air', amount: 10, description: null },
    ];
    expect(parseFeeLines(feeLinesToMaps(lines))).toEqual(lines);
  });
  it('parses legacy maps without a description as null', () => {
    expect(parseFeeLines([{ id: 'f1', name: 'Air', amount: 10 }])).toEqual([
      { id: 'f1', name: 'Air', amount: 10, description: null },
    ]);
  });
});

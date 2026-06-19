import { describe, expect, it } from 'vitest';
import { parseBarcodes, diffBarcodeClaims } from './barcodes';

describe('parseBarcodes', () => {
  it('reads the barcodes array, trimming and dropping empties', () => {
    expect(parseBarcodes({ barcodes: [' 123 ', '', '456'] })).toEqual(['123', '456']);
  });
  it('lifts a legacy singular barcode and unions it (de-duped)', () => {
    expect(parseBarcodes({ barcodes: ['123'], barcode: '123' })).toEqual(['123']);
    expect(parseBarcodes({ barcode: '789' })).toEqual(['789']);
  });
  it('tolerates missing / non-array / non-string inputs', () => {
    expect(parseBarcodes({})).toEqual([]);
    expect(parseBarcodes({ barcodes: 'nope' })).toEqual([]);
    expect(parseBarcodes({ barcodes: [1, null, 'x'] })).toEqual(['x']);
  });
  it('is case-sensitive (barcodes are exact tokens)', () => {
    expect(parseBarcodes({ barcodes: ['abc', 'ABC'] })).toEqual(['abc', 'ABC']);
  });
});

describe('diffBarcodeClaims', () => {
  it('computes added and removed by normalized key', () => {
    expect(diffBarcodeClaims(['1', '2'], ['2', '3'])).toEqual({ added: ['3'], removed: ['1'] });
  });
  it('treats trim-equal codes as unchanged', () => {
    expect(diffBarcodeClaims(['1'], [' 1 '])).toEqual({ added: [], removed: [] });
  });
  it('is empty on a no-op', () => {
    expect(diffBarcodeClaims(['1', '2'], ['1', '2'])).toEqual({ added: [], removed: [] });
  });
  it('is case-sensitive', () => {
    expect(diffBarcodeClaims(['abc'], ['ABC'])).toEqual({ added: ['ABC'], removed: ['abc'] });
  });
});

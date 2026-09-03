import { describe, expect, it } from 'vitest';
import { TAG_COLORS, normalizeTagColor, tagChipStyle } from './tagColors';

describe('tagColors', () => {
  it('exposes the eight canonical tokens', () => {
    expect(TAG_COLORS).toEqual([
      'gray', 'red', 'amber', 'green', 'teal', 'blue', 'purple', 'pink',
    ]);
  });
  it('normalizes unknown / missing values to gray', () => {
    expect(normalizeTagColor('green')).toBe('green');
    expect(normalizeTagColor('chartreuse')).toBe('gray');
    expect(normalizeTagColor(undefined)).toBe('gray');
    expect(normalizeTagColor(null)).toBe('gray');
    expect(normalizeTagColor(42)).toBe('gray');
  });
  it('every token has a chip style', () => {
    for (const c of TAG_COLORS) {
      const s = tagChipStyle(c);
      expect(s.bg).toMatch(/^#/);
      expect(s.fg).toMatch(/^#/);
    }
  });
});

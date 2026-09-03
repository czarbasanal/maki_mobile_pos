import { describe, expect, it } from 'vitest';
import { marginPct, marginToneClass } from './margin';

describe('marginPct', () => {
  it('is null without a positive price', () => {
    expect(marginPct(0, 10)).toBeNull();
    expect(marginPct(-5, 10)).toBeNull();
  });
  it('rounds (price − cost) / price to a whole percent', () => {
    expect(marginPct(100, 40)).toBe(60);
    expect(marginPct(150, 100)).toBe(33);
    expect(marginPct(100, 0)).toBe(100);
  });
});

describe('marginToneClass', () => {
  it('maps the shared thresholds', () => {
    expect(marginToneClass(null)).toBe('text-ink-3');
    expect(marginToneClass(50)).toBe('text-pos');
    expect(marginToneClass(49)).toBe('text-ink-2');
    expect(marginToneClass(25)).toBe('text-ink-2');
    expect(marginToneClass(24)).toBe('text-neg');
  });
});

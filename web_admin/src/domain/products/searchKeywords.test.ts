import { describe, expect, it } from 'vitest';
import { generateSearchKeywords, toSearchKeywords } from './searchKeywords';

describe('toSearchKeywords', () => {
  it('emits the length-1..n prefixes of each word, lowercased', () => {
    expect(toSearchKeywords('Hi World')).toEqual([
      'h', 'hi', 'w', 'wo', 'wor', 'worl', 'world',
    ]);
  });
});

describe('generateSearchKeywords', () => {
  it('unions prefixes across parts, skips null/empty, dedupes', () => {
    expect(generateSearchKeywords(['ab', null, 'ab cd', '']).sort()).toEqual(
      ['a', 'ab', 'c', 'cd'].sort(),
    );
  });
});

import { describe, expect, it } from 'vitest';
import {
  generateSku,
  slugifyForSku,
  normalizeSku,
  isValidSku,
  normalizeBarcode,
  isClaimableBarcode,
} from './sku';

// rand() => 0 makes the random suffix all 'A' (alphabet[0]).
const zero = () => 0;

describe('slugifyForSku', () => {
  it('uppercases and strips non-alphanumerics', () => {
    expect(slugifyForSku('Milk Chocolate 500g!')).toBe('MILKCHOCOLATE500G');
  });
});

describe('generateSku', () => {
  it('keeps the first letter, drops later vowels, caps at 10, adds a 6-char suffix', () => {
    expect(generateSku('Milk Chocolate 500g Box', zero)).toBe('MLKCHCLT50-AAAAAA');
  });

  it('keeps a leading vowel so short names stay recognisable', () => {
    expect(generateSku('Ice', zero)).toBe('IC-AAAAAA');
  });

  it('falls back to the SKU- prefix + 8-char suffix when the name has no usable chars', () => {
    expect(generateSku('!!!', zero)).toBe('SKU-AAAAAAAA');
  });
});

describe('normalizeSku', () => {
  it('trims and uppercases', () => {
    expect(normalizeSku('  abc-1 ')).toBe('ABC-1');
    expect(normalizeSku('ABC-1')).toBe('ABC-1');
    expect(normalizeSku('aBc-1')).toBe('ABC-1');
  });

  it('is idempotent', () => {
    const once = normalizeSku('  abc-1 ');
    expect(normalizeSku(once)).toBe(once);
  });
});

describe('isValidSku', () => {
  it('accepts letters, numbers, and hyphens up to 50 chars', () => {
    expect(isValidSku('ABC-1')).toBe(true);
    expect(isValidSku('A'.repeat(50))).toBe(true);
  });

  it('rejects empty, slash, whitespace, and over-50', () => {
    expect(isValidSku('')).toBe(false);
    expect(isValidSku('PRD/001')).toBe(false);
    expect(isValidSku('A B')).toBe(false);
    expect(isValidSku('A'.repeat(51))).toBe(false);
  });
});

describe('normalizeBarcode', () => {
  it('trims and preserves case (NOT uppercased)', () => {
    expect(normalizeBarcode(' Abc/12 ')).toBe('Abc/12');
    expect(normalizeBarcode('4800123')).toBe('4800123');
    expect(normalizeBarcode('abc')).toBe('abc');
  });

  it('is idempotent', () => {
    const once = normalizeBarcode('  4800123 ');
    expect(normalizeBarcode(once)).toBe(once);
  });
});

describe('isClaimableBarcode', () => {
  it('accepts a normal code', () => {
    expect(isClaimableBarcode('4800123456789')).toBe(true);
  });

  it('rejects empty, slash, dot/dotdot, and dunder keys', () => {
    expect(isClaimableBarcode('')).toBe(false);
    expect(isClaimableBarcode('a/b')).toBe(false);
    expect(isClaimableBarcode('.')).toBe(false);
    expect(isClaimableBarcode('..')).toBe(false);
    expect(isClaimableBarcode('__x__')).toBe(false);
  });
});

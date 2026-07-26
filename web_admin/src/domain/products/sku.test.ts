import { describe, expect, it } from 'vitest';
import {
  generateSku,
  slugifyForSku,
  normalizeSku,
  isValidSku,
  normalizeBarcode,
  isClaimableBarcode,
  composeAutoSku,
  matchesAutoPattern,
  sequenceOf,
  displaySku,
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

describe('composeAutoSku', () => {
  it('pads the category code to 4 digits then appends the zero-padded sequence', () => {
    expect(composeAutoSku('0007', 153)).toBe('00070153');
    expect(composeAutoSku('0001', 1)).toBe('00010001');
    expect(composeAutoSku('1234', 9999)).toBe('12349999');
  });

  it('throws unless the category code is exactly 4 digits', () => {
    expect(() => composeAutoSku('007', 1)).toThrow();
    expect(() => composeAutoSku('00070', 1)).toThrow();
    expect(() => composeAutoSku('ABCD', 1)).toThrow();
  });

  it('throws unless the sequence is between 1 and 9999', () => {
    expect(() => composeAutoSku('0007', 0)).toThrow();
    expect(() => composeAutoSku('0007', 10000)).toThrow();
  });
});

describe('matchesAutoPattern', () => {
  it('accepts 8 digits starting with the category code', () => {
    expect(matchesAutoPattern('00070153', '0007')).toBe(true);
    expect(matchesAutoPattern('00010001', '0001')).toBe(true);
  });

  it('rejects the wrong length', () => {
    expect(matchesAutoPattern('0007015', '0007')).toBe(false);
    expect(matchesAutoPattern('000701530', '0007')).toBe(false);
  });

  it('rejects the wrong prefix', () => {
    expect(matchesAutoPattern('00080153', '0007')).toBe(false);
  });

  it('rejects non-numeric skus', () => {
    expect(matchesAutoPattern('0007ABCD', '0007')).toBe(false);
    expect(matchesAutoPattern('MLK-A3B7', '0007')).toBe(false);
  });

  it('returns false (not a throw) for a malformed category code', () => {
    expect(matchesAutoPattern('00070153', '')).toBe(false);
    expect(matchesAutoPattern('00070153', '007')).toBe(false);
    expect(matchesAutoPattern('00070153', '00071')).toBe(false);
    expect(matchesAutoPattern('00070153', 'ABCD')).toBe(false);
  });
});

describe('sequenceOf', () => {
  it('extracts the last 4 digits as an int', () => {
    expect(sequenceOf('00070153')).toBe(153);
    expect(sequenceOf('00010001')).toBe(1);
    expect(sequenceOf('12349999')).toBe(9999);
  });
});

describe('displaySku', () => {
  it('formats an 8-digit numeric sku as XXXX-XXXX', () => {
    expect(displaySku('00070153')).toBe('0007-0153');
    expect(displaySku('00010001')).toBe('0001-0001');
    expect(displaySku('12349999')).toBe('1234-9999');
  });

  it('leaves non-8-digit or non-numeric skus unchanged', () => {
    expect(displaySku('MLK-A3B7')).toBe('MLK-A3B7');
    expect(displaySku('0007015')).toBe('0007015');
    expect(displaySku('000701530')).toBe('000701530');
    expect(displaySku('SKU-ABCD1234')).toBe('SKU-ABCD1234');
  });

  it('passes a variation-suffixed 8-digit-plus sku through unchanged', () => {
    expect(displaySku('00070153-1')).toBe('00070153-1');
  });
});

import { describe, expect, it } from 'vitest';
import { generateSku, slugifyForSku } from './sku';

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

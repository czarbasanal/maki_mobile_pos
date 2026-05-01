// Mirror of lib/domain/entities/cost_code_entity.dart. Encodes prices as
// letters to hide cost from unauthorized users. Default mapping must match
// Dart exactly — products written from one app must decode correctly on the
// other.
//
// Default mapping:
//   1 → N   2 → B   3 → Q   4 → M   5 → F
//   6 → Z   7 → V   8 → L   9 → J   0 → S
//   00  → SC    000 → SCS

export interface CostCode {
  digitToLetter: Record<string, string>;
  doubleZeroCode: string;
  tripleZeroCode: string;
  updatedAt: Date | null;
  updatedBy: string | null;
}

export const defaultCostCode: CostCode = {
  digitToLetter: {
    '1': 'N',
    '2': 'B',
    '3': 'Q',
    '4': 'M',
    '5': 'F',
    '6': 'Z',
    '7': 'V',
    '8': 'L',
    '9': 'J',
    '0': 'S',
  },
  doubleZeroCode: 'SC',
  tripleZeroCode: 'SCS',
  updatedAt: null,
  updatedBy: null,
};

export function letterToDigit(cc: CostCode): Record<string, string> {
  const reverse: Record<string, string> = {};
  for (const [digit, letter] of Object.entries(cc.digitToLetter)) {
    reverse[letter] = digit;
  }
  reverse[cc.doubleZeroCode] = '00';
  reverse[cc.tripleZeroCode] = '000';
  return reverse;
}

// Encodes a cost amount to a letter code. Truncates decimals — cost codes
// only encode the whole number portion.
export function encodeCostCode(cc: CostCode, cost: number): string {
  const whole = Math.trunc(cost);
  if (whole <= 0) return cc.digitToLetter['0'] ?? 'S';

  const s = String(whole);
  let out = '';
  let i = 0;
  while (i < s.length) {
    const remaining = s.length - i;
    if (remaining >= 3 && s[i] === '0' && s[i + 1] === '0' && s[i + 2] === '0') {
      out += cc.tripleZeroCode;
      i += 3;
      continue;
    }
    if (remaining >= 2 && s[i] === '0' && s[i + 1] === '0') {
      out += cc.doubleZeroCode;
      i += 2;
      continue;
    }
    out += cc.digitToLetter[s[i]] ?? '?';
    i += 1;
  }
  return out;
}

// Decodes a letter code back to a cost amount. Returns null if the code
// contains a letter not present in the mapping.
export function decodeCostCode(cc: CostCode, code: string): number | null {
  if (!code) return null;
  const reverse = letterToDigit(cc);
  let out = '';
  let i = 0;
  while (i < code.length) {
    if (i + cc.tripleZeroCode.length <= code.length) {
      const triple = code.slice(i, i + cc.tripleZeroCode.length);
      if (triple === cc.tripleZeroCode) {
        out += '000';
        i += cc.tripleZeroCode.length;
        continue;
      }
    }
    if (i + cc.doubleZeroCode.length <= code.length) {
      const double = code.slice(i, i + cc.doubleZeroCode.length);
      if (double === cc.doubleZeroCode) {
        out += '00';
        i += cc.doubleZeroCode.length;
        continue;
      }
    }
    const digit = reverse[code[i]];
    if (digit === undefined) return null;
    out += digit;
    i += 1;
  }
  const n = Number.parseFloat(out);
  return Number.isNaN(n) ? null : n;
}

// True when two mappings encode identically (ignoring updatedAt/updatedBy
// metadata). Used to short-circuit "reset to default" when already default.
export function costCodeEqualsMapping(a: CostCode, b: CostCode): boolean {
  if (a.doubleZeroCode !== b.doubleZeroCode) return false;
  if (a.tripleZeroCode !== b.tripleZeroCode) return false;
  for (let i = 0; i < 10; i += 1) {
    const d = String(i);
    if (a.digitToLetter[d] !== b.digitToLetter[d]) return false;
  }
  return true;
}

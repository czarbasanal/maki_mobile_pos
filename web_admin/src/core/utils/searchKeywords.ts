// Mirrors lib/core/extensions/string_extensions.dart#toSearchKeywords. Used
// to populate the `searchKeywords` array on Firestore docs so the Flutter app
// can run array-contains queries against them.

const DEFAULT_MIN = 1;
const DEFAULT_MAX = 10;

export function toSearchKeywords(
  input: string,
  { min = DEFAULT_MIN, max = DEFAULT_MAX }: { min?: number; max?: number } = {},
): string[] {
  const seen = new Set<string>();
  const words = input.toLowerCase().split(/\s+/);
  for (const word of words) {
    if (!word) continue;
    const top = Math.min(word.length, max);
    for (let i = min; i <= top; i += 1) {
      seen.add(word.slice(0, i));
    }
  }
  return Array.from(seen);
}

export function supplierSearchKeywords(
  name: string,
  contactPerson?: string | null,
  address?: string | null,
): string[] {
  const out = new Set<string>(toSearchKeywords(name));
  if (contactPerson) {
    for (const k of toSearchKeywords(contactPerson)) out.add(k);
  }
  if (address) {
    const firstWords = address.toLowerCase().split(/\s+/).slice(0, 3);
    for (const word of firstWords) {
      if (word.length > 2) {
        for (const k of toSearchKeywords(word)) out.add(k);
      }
    }
  }
  return Array.from(out);
}

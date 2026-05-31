// Port of lib/core/extensions/string_extensions.dart `toSearchKeywords` and
// product_model `_generateSearchKeywords`. Mobile search uses an
// arrayContainsAny query over this list, so web-created products must tokenize
// identically to be findable.
export function toSearchKeywords(value: string, minLength = 1, maxLength = 10): string[] {
  const out = new Set<string>();
  for (const word of value.toLowerCase().split(/\s+/)) {
    if (word.length === 0) continue;
    for (let i = minLength; i <= word.length && i <= maxLength; i += 1) {
      out.add(word.slice(0, i));
    }
  }
  return [...out];
}

export function generateSearchKeywords(parts: (string | null | undefined)[]): string[] {
  const out = new Set<string>();
  for (const part of parts) {
    if (!part) continue;
    for (const kw of toSearchKeywords(part)) out.add(kw);
  }
  return [...out];
}

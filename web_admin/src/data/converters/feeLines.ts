import type { FeeLine } from '@/domain/entities';

/** Parse an inline `feeLines` array from Firestore into FeeLine[]. */
export function parseFeeLines(value: unknown): FeeLine[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw, i) => {
    const m = (raw ?? {}) as Record<string, unknown>;
    return {
      id: typeof m.id === 'string' ? m.id : `fee-${i}`,
      name: typeof m.name === 'string' ? m.name : '',
      amount: Number(m.amount ?? 0),
    };
  });
}

/** Serialize FeeLine[] to inline Firestore maps (id included). */
export function feeLinesToMaps(lines: FeeLine[]): object[] {
  return lines.map((l) => ({ id: l.id, name: l.name, amount: l.amount }));
}

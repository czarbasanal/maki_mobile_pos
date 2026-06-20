import type { LaborLine } from '@/domain/entities';

/** Parse an inline `laborLines` array from Firestore into LaborLine[]. */
export function parseLaborLines(value: unknown): LaborLine[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw, i) => {
    const m = (raw ?? {}) as Record<string, unknown>;
    return {
      id: typeof m.id === 'string' ? m.id : `labor-${i}`,
      description: typeof m.description === 'string' ? m.description : '',
      fee: Number(m.fee ?? 0),
    };
  });
}

/** Serialize LaborLine[] to inline Firestore maps (id included). */
export function laborLinesToMaps(lines: LaborLine[]): object[] {
  return lines.map((l) => ({ id: l.id, description: l.description, fee: l.fee }));
}

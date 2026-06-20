import type { LaborLine } from '@/domain/entities/LaborLine';

/** Labor lines that count: a charge requires a non-blank description. */
export function describedLaborLines(lines: LaborLine[]): LaborLine[] {
  return lines.filter((l) => l.description.trim() !== '');
}

/** Σ fee of the described labor lines (full price, never discounted). */
export function cartLaborSubtotal(lines: LaborLine[]): number {
  return describedLaborLines(lines).reduce((sum, l) => sum + (l.fee || 0), 0);
}

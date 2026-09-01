import type { LaborLine } from '@/domain/entities/LaborLine';

/** Labor lines that count: a charge requires a non-blank description. */
export function describedLaborLines(lines: LaborLine[]): LaborLine[] {
  return lines.filter((l) => l.description.trim() !== '');
}

/** Σ fee of the described labor lines (full price, never discounted). */
export function cartLaborSubtotal(lines: LaborLine[]): number {
  return describedLaborLines(lines).reduce((sum, l) => sum + (l.fee || 0), 0);
}

/**
 * Mobile-parity checkout/JO-save gate. Unlike `describedLaborLines` (which
 * silently drops incomplete rows at write time), this BLOCKS: labor money
 * never leaves the register unattributed or half-described.
 */
export function laborValidationError(
  lines: LaborLine[],
  mechanicId: string | null,
): string | null {
  if (lines.length === 0) return null;
  if (lines.some((l) => l.description.trim() === '')) {
    return 'Each labor line needs a description.';
  }
  if (lines.some((l) => !(l.fee > 0))) {
    return 'Each labor fee must be greater than ₱0.';
  }
  if (mechanicId === null) {
    return 'Assign a mechanic before saving labor.';
  }
  return null;
}

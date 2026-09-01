// Mirror of lib/domain/entities/motorcycle_model_entity.dart +
// lib/core/utils/motorcycle_model_name.dart — the admin-managed,
// cashier-addable model list backing the Job Order picker.
export interface MotorcycleModel {
  id: string;
  name: string;
  isActive: boolean;
}

/** Canonical display form: trimmed, internal whitespace collapsed, case kept. */
export function canonicalModelName(raw: string): string {
  return raw.trim().replace(/\s+/g, ' ');
}

/** Case-insensitive dedup key — "  nmax " and "Nmax" reuse one row. */
export function normalizedModelKey(raw: string): string {
  return canonicalModelName(raw).toLowerCase();
}

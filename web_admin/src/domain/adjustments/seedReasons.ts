// Seed defaults for adjustment reasons. Auto-seeded when the list is empty
// at first dialog open, plus a "Seed defaults" action in the editor.
// See spec table: docs/superpowers/specs/2026-09-04-stock-adjustment-audit-design.md
export const SEED_REASONS = [
  { name: 'Delivery', requiresNote: false },
  { name: 'Count correction', requiresNote: true },
  { name: 'Damaged', requiresNote: true },
  { name: 'Lost', requiresNote: true },
  { name: 'Returned', requiresNote: false },
  { name: 'Transfer', requiresNote: false },
] as const;

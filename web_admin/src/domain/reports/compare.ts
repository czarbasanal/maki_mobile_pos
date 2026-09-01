// Prior-period comparison math for KPI delta chips (spec §5.1).
export function percentDelta(current: number, previous: number): number | null {
  if (!Number.isFinite(previous) || previous <= 0) return null;
  return (current - previous) / previous;
}

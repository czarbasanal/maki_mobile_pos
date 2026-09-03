// The app-wide margin: `(price − cost) / price`, and the one set of
// thresholds coloring it (product-modal guide §2: the Inventory table, the
// Receiving detail and the product modal must never disagree on what a
// "good" margin is).
export function marginPct(price: number, cost: number): number | null {
  if (price <= 0) return null;
  return Math.round(((price - cost) / price) * 100);
}

/** Text-color class for a margin: ≥50% healthy, 25–49% ordinary, <25% thin. */
export function marginToneClass(pct: number | null): string {
  if (pct === null) return 'text-ink-3';
  return pct >= 50 ? 'text-pos' : pct >= 25 ? 'text-ink-2' : 'text-neg';
}

// Picks the price_history reason string for an edit, matching the mobile
// literals so derivePriceHistorySource renders "Manual edit". Returns null when
// neither cost nor price moved by more than one centavo. Pure -> relative imports.
const EPS = 0.01;

export function priceHistoryReason(
  oldCost: number,
  oldPrice: number,
  newCost: number,
  newPrice: number,
): string | null {
  const costChanged = Math.abs(newCost - oldCost) > EPS;
  const priceChanged = Math.abs(newPrice - oldPrice) > EPS;
  if (costChanged && priceChanged) return 'Price + cost update';
  if (costChanged) return 'Cost update';
  if (priceChanged) return 'Price update';
  return null;
}

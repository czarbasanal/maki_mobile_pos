// Currency formatter. The Flutter app uses ₱ (PHP) without grouping the
// fractional digits — match that for visual parity.

const formatter = new Intl.NumberFormat('en-PH', {
  style: 'currency',
  currency: 'PHP',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export function formatMoney(amount: number): string {
  if (!Number.isFinite(amount)) return '₱0.00';
  return formatter.format(amount);
}

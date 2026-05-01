// Shared tonal palette used for icon badges across the admin (sidebar nav,
// dashboard summary tiles, inventory rows, etc.). Class strings are static
// literals so Tailwind's content scanner picks them up.

export type Tone = 'yellow' | 'green' | 'blue' | 'orange' | 'red' | 'violet';

// Light tinted background + saturated icon stroke. Use on small icons
// rendered inside a 20–24 px badge.
export const toneBadgeClasses: Record<Tone, string> = {
  yellow: 'bg-yellow-50 text-yellow-600',
  green: 'bg-green-50 text-green-600',
  blue: 'bg-blue-50 text-blue-600',
  orange: 'bg-orange-50 text-orange-600',
  red: 'bg-red-50 text-red-600',
  violet: 'bg-violet-50 text-violet-600',
};

// Plain colored stroke — no background. Use on larger icons rendered
// in-line on a card surface.
export const toneStrokeClasses: Record<Tone, string> = {
  yellow: 'text-yellow-500',
  green: 'text-green-500',
  blue: 'text-blue-500',
  orange: 'text-orange-500',
  red: 'text-red-500',
  violet: 'text-violet-500',
};

import { clsx, type ClassValue } from 'clsx';
import { extendTailwindMerge } from 'tailwind-merge';

// tailwind-merge only knows Tailwind's STOCK class names. Our custom
// fontSize tokens (text-cell, text-ctl-sm, …) look exactly like text-COLOR
// utilities to it, so a size followed by a color in the same cn() call got
// silently DELETED (e.g. cn('text-ctl-sm …', 'text-ink-2') rendered with no
// font size at all). Registering every custom size token in the font-size
// class group fixes the classification.
//
// KEEP IN SYNC with tailwind.config.ts's fontSize keys (both the new-skin
// scale and the legacy named scale from core/theme/tokens.ts). The test in
// cn.test.ts pins the behavior.
const FONT_SIZE_TOKENS = [
  // New skin (tailwind.config.ts)
  'page-title',
  'page-sub',
  'card-title',
  'kpi',
  'kpi-label',
  'micro',
  'micro-caps',
  'group-caps',
  'cell',
  'amount',
  'nav',
  'pill',
  'axis',
  'inv-figure',
  'brand',
  'ctl-sm',
  'ctl-md',
  'ctl-lg',
  // Legacy named scale (core/theme/tokens.ts)
  'headingXL',
  'headingLarge',
  'headingMedium',
  'headingSmall',
  'bodyLarge',
  'bodyMedium',
  'bodySmall',
  'labelLarge',
  'labelMedium',
  'labelSmall',
  'priceXL',
  'priceLarge',
  'priceMedium',
  'priceSmall',
  'code',
  'costCode',
  'badge',
];

const twMerge = extendTailwindMerge({
  extend: {
    classGroups: {
      'font-size': [{ text: FONT_SIZE_TOKENS }],
    },
  },
});

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

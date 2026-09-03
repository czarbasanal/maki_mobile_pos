// The eight tag color tokens, stored verbatim in product_tags.color. Keep in
// lockstep with lib/core/constants/tag_colors.dart — the same token must
// render as the same hue on both surfaces.
export const TAG_COLORS = [
  'gray', 'red', 'amber', 'green', 'teal', 'blue', 'purple', 'pink',
] as const;

export type TagColor = (typeof TAG_COLORS)[number];

export function normalizeTagColor(v: unknown): TagColor {
  return TAG_COLORS.includes(v as TagColor) ? (v as TagColor) : 'gray';
}

// Muted tint + readable text per token — soft chips, not saturated badges.
const STYLES: Record<TagColor, { bg: string; fg: string }> = {
  gray:   { bg: '#ECEFF1', fg: '#455A64' },
  red:    { bg: '#FDE8E8', fg: '#B03A34' },
  amber:  { bg: '#FBF0DC', fg: '#8A6116' },
  green:  { bg: '#E5F2E5', fg: '#2E7D32' },
  teal:   { bg: '#E0F0EF', fg: '#1F6E66' },
  blue:   { bg: '#E3EDF8', fg: '#2A5D8F' },
  purple: { bg: '#EEE8F7', fg: '#6A4FA3' },
  pink:   { bg: '#F9E7F0', fg: '#A34D77' },
};

export function tagChipStyle(color: TagColor): { bg: string; fg: string } {
  return STYLES[color];
}

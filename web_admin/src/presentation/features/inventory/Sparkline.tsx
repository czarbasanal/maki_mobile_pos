import { sparklinePath } from '@/domain/products/priceHistory';

const WIDTH = 320;
const HEIGHT = 44;

/** Axis-less inline-SVG sparkline. Inherits colour from `currentColor`; renders
 *  nothing for fewer than two points (caller shows a caption instead). */
export function Sparkline({ values }: { values: number[] }) {
  const d = sparklinePath(values, WIDTH, HEIGHT);
  if (!d) return null;
  return (
    <svg
      viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
      preserveAspectRatio="none"
      className="h-11 w-full"
      aria-hidden
    >
      <path d={d} fill="none" stroke="currentColor" strokeWidth={2} />
    </svg>
  );
}

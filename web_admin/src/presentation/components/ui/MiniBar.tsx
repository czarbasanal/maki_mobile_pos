// The 5px stock rail (Inventory guide §4): --surface-3 track, colored fill.
// A non-zero share always renders at least 4% so a count of 1 stays visible.
import { cn } from '@/core/utils/cn';

export function MiniBar({
  pct,
  color,
  width,
}: {
  /** 0–100. */
  pct: number;
  /** CSS color for the fill — pass a token var, e.g. 'var(--pos)'. */
  color: string;
  /** Fixed rail width (e.g. '34px' for the profit table's margin column).
   *  Omit to stretch across the cell. */
  width?: string;
}) {
  const fill = pct <= 0 ? 0 : Math.min(100, Math.max(4, pct));
  return (
    <div
      className={cn(
        'h-[5px] overflow-hidden rounded-[3px] bg-surface-3',
        width ? 'shrink-0' : 'min-w-[52px] flex-1',
      )}
      style={width ? { width } : undefined}
    >
      <div
        className="h-full rounded-[3px]"
        style={{ width: `${fill}%`, background: color }}
      />
    </div>
  );
}

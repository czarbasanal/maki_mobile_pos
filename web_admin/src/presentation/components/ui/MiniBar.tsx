// The 5px stock rail (Inventory guide §4): --surface-3 track, colored fill.
// A non-zero share always renders at least 4% so a count of 1 stays visible.
export function MiniBar({
  pct,
  color,
}: {
  /** 0–100. */
  pct: number;
  /** CSS color for the fill — pass a token var, e.g. 'var(--pos)'. */
  color: string;
}) {
  const width = pct <= 0 ? 0 : Math.min(100, Math.max(4, pct));
  return (
    <div className="h-[5px] min-w-[52px] flex-1 overflow-hidden rounded-[3px] bg-surface-3">
      <div
        className="h-full rounded-[3px]"
        style={{ width: `${width}%`, background: color }}
      />
    </div>
  );
}

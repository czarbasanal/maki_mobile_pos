// A facts-strip tile (Sale/Receiving detail guides §B): tracked uppercase
// label, 13.5/600 value, one dim sub line. Host the tiles in a
// grid-cols-[repeat(auto-fit,minmax(...,1fr))] with divide-x divide-line-2.
import { cn } from '@/core/utils/cn';

export function Fact({
  label,
  value,
  sub,
  mono,
  dim,
}: {
  label: string;
  value: string;
  sub: string;
  mono?: boolean;
  /** Value known to be absent (e.g. "No supplier") — renders in --text-3. */
  dim?: boolean;
}) {
  return (
    <div className="flex min-w-0 flex-col gap-[5px] px-5 py-3.5">
      <span className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">{label}</span>
      <span
        className={cn(
          'text-[13.5px] font-semibold tracking-[-0.2px]',
          dim ? 'text-ink-3' : 'text-ink',
          mono && 'font-mono',
        )}
      >
        {value}
      </span>
      <span className="text-[11px] text-ink-3">{sub}</span>
    </div>
  );
}

// Summary-row money card (Inventory/Receiving guides §2): 11.5px label,
// 22px mono value with tnum, 11px basis note so the number isn't ambiguous.
import { cn } from '@/core/utils/cn';

export function MoneyCard({
  label,
  value,
  note,
  positive,
}: {
  label: string;
  value: string;
  note: string;
  /** A result rather than a measurement (e.g. Expected profit) — --pos. */
  positive?: boolean;
}) {
  return (
    <div className="flex flex-col gap-2 rounded-card border border-line bg-surface px-[17px] py-[15px] shadow-card">
      <span className="text-[11.5px] font-medium text-ink-2">{label}</span>
      <span
        className={cn(
          'tnum font-mono text-[22px] font-semibold tracking-[-1px]',
          positive ? 'text-pos' : 'text-ink',
        )}
      >
        {value}
      </span>
      <span className="text-[11px] text-ink-3">{note}</span>
    </div>
  );
}

// Amber lock notice shown to daily-only roles in place of the range control —
// mirrors mobile's ReportsWarningBanner copy exactly.
import { LockClosedIcon } from '@heroicons/react/24/outline';

export function DailyLockNotice({ children }: { children: string }) {
  return (
    <div className="flex items-center gap-2 rounded-ctl border border-accent-line bg-accent-soft px-3 py-2">
      <LockClosedIcon className="h-3.5 w-3.5 shrink-0 text-accent-text" />
      <p className="text-ctl-sm text-accent-text">{children}</p>
    </div>
  );
}

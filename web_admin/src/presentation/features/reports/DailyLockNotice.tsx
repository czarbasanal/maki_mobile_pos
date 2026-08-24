// Amber lock notice shown to daily-only roles in place of the range picker —
// mirrors mobile's ReportsWarningBanner copy exactly.
import { LockClosedIcon } from '@heroicons/react/24/outline';

export function DailyLockNotice({ children }: { children: string }) {
  return (
    <div className="flex items-center gap-tk-sm rounded-md border border-warning-light bg-warning-light/30 px-tk-md py-tk-sm">
      <LockClosedIcon className="h-4 w-4 shrink-0 text-light-text-secondary" />
      <p className="text-bodySmall text-light-text">{children}</p>
    </div>
  );
}

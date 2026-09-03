// The detail pages' back affordance: a bordered chevron pill above the card
// (receiving-detail reference), shared so the treatment can't drift.
import { ChevronLeftIcon } from '@heroicons/react/24/outline';

export function BackButton({ label = 'Back', onClick }: { label?: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-fit items-center gap-1.5 whitespace-nowrap rounded-ctl border border-line bg-surface py-2 pl-[11px] pr-3.5 text-ctl-sm font-medium text-ink-2 shadow-card hover:border-accent-line hover:text-ink"
    >
      <ChevronLeftIcon className="h-3.5 w-3.5 shrink-0" />
      {label}
    </button>
  );
}

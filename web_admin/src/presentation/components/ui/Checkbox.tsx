// The tokenized 17px checkbox (PO guide §D / sign-in card): --accent fill
// with --accent-line border and an --accent-ink tick when checked — never a
// native checkbox, which can't be tokenized.
import { CheckIcon } from '@heroicons/react/24/outline';
import { cn } from '@/core/utils/cn';

export function Checkbox({
  checked,
  indeterminate = false,
  onChange,
  label,
}: {
  checked: boolean;
  /** Header all/none/partial state — renders a dash. */
  indeterminate?: boolean;
  onChange: () => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={indeterminate ? 'mixed' : checked}
      aria-label={label}
      onClick={(e) => {
        e.stopPropagation();
        onChange();
      }}
      className={cn(
        'flex h-[17px] w-[17px] shrink-0 items-center justify-center rounded-[5px] border',
        checked || indeterminate
          ? 'border-accent-line bg-accent'
          : 'border-line bg-surface-2',
      )}
    >
      {indeterminate ? (
        <span aria-hidden className="h-[2px] w-2 rounded bg-accent-ink" />
      ) : checked ? (
        <CheckIcon className="h-3 w-3 stroke-[3] text-accent-ink" />
      ) : null}
    </button>
  );
}

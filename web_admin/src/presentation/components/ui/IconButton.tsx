import { clsx } from 'clsx';
import type { ButtonHTMLAttributes } from 'react';

export interface IconButtonProps
  extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className' | 'style' | 'title' | 'aria-label'> {
  /** Required — becomes both tooltip and accessible name. */
  title: string;
  size?: 22 | 28;
  /** 'danger' hovers into the negative tint (destructive affordances). */
  tone?: 'default' | 'danger';
}

export function IconButton({
  title,
  size = 22,
  tone = 'default',
  children,
  type = 'button',
  onKeyDown,
  ...rest
}: IconButtonProps) {
  return (
    <button
      type={type}
      title={title}
      aria-label={title}
      // Enter/Space on an in-row icon button (CopyButton and friends) must
      // not bubble into the row's keyboard activation — same containment as
      // the tokenized Checkbox.
      onKeyDown={(e) => {
        e.stopPropagation();
        onKeyDown?.(e);
      }}
      className={clsx(
        'inline-flex shrink-0 items-center justify-center rounded-chip text-ink-3 transition-[color]',
        tone === 'danger' ? 'hover:bg-neg-soft hover:text-neg' : 'hover:bg-surface-3 hover:text-ink-2',
        size === 22 ? 'h-[22px] w-[22px]' : 'h-7 w-7',
      )}
      {...rest}
    >
      {children}
    </button>
  );
}

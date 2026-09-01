import { clsx } from 'clsx';
import type { ButtonHTMLAttributes } from 'react';

export interface IconButtonProps
  extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className' | 'style' | 'title' | 'aria-label'> {
  /** Required — becomes both tooltip and accessible name. */
  title: string;
  size?: 22 | 28;
}

export function IconButton({ title, size = 22, children, type = 'button', ...rest }: IconButtonProps) {
  return (
    <button
      type={type}
      title={title}
      aria-label={title}
      className={clsx(
        'inline-flex shrink-0 items-center justify-center rounded-chip text-ink-3 transition-[color] hover:bg-surface-3 hover:text-ink-2',
        size === 22 ? 'h-[22px] w-[22px]' : 'h-7 w-7',
      )}
      {...rest}
    >
      {children}
    </button>
  );
}

import { clsx } from 'clsx';
import type { ButtonHTMLAttributes, ReactNode } from 'react';
import { Spinner } from '../common/LoadingView';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md';

const variantCls: Record<ButtonVariant, string> = {
  primary: 'bg-accent text-accent-ink font-semibold hover:brightness-95',
  secondary: 'border border-line bg-surface text-ink-2 hover:text-ink',
  ghost: 'bg-transparent text-ink-2 hover:bg-surface-2',
  danger: 'bg-neg-soft font-medium text-neg hover:brightness-95',
};

const sizeCls: Record<ButtonSize, string> = {
  sm: 'px-3 py-[7px] text-ctl-sm',
  md: 'px-3.5 py-[9px] text-ctl-md',
};

export interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className' | 'style'> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  icon?: ReactNode;
  loading?: boolean;
}

export function Button({
  variant = 'secondary',
  size = 'md',
  icon,
  loading = false,
  disabled,
  children,
  type = 'button',
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled || loading}
      className={clsx(
        'inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-ctl font-medium transition-opacity',
        variantCls[variant],
        sizeCls[size],
        (disabled || loading) && 'pointer-events-none opacity-50',
      )}
      {...rest}
    >
      {loading ? <Spinner className="h-3.5 w-3.5" /> : icon}
      {children}
    </button>
  );
}

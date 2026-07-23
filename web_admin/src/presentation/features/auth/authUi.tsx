// Shared visual bits for the AuthLayout pages (login, forgot-password).

import { ExclamationCircleIcon, XMarkIcon } from '@heroicons/react/24/outline';
import { cn } from '@/core/utils/cn';

export function inputCls(hasError: boolean): string {
  return cn(
    'w-full rounded-md border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none transition-colors',
    // Thicker outline on focus, no glow: drop the soft ring shadow and use a
    // real CSS outline (no layout shift) layered just outside the border.
    'focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0',
    hasError ? 'border-error focus:border-error focus:outline-error' : 'border-light-border',
  );
}

export function Field({
  label,
  error,
  input,
}: {
  label: string;
  error?: string;
  input: React.ReactNode;
}) {
  return (
    <label className="block space-y-tk-xs">
      <span className="text-bodySmall font-medium text-light-text">{label}</span>
      {input}
      {error ? <span className="block text-[12px] text-error">{error}</span> : null}
    </label>
  );
}

export function ErrorBanner({ message, onDismiss }: { message: string; onDismiss: () => void }) {
  return (
    <div className="flex items-start gap-tk-sm rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-error-dark">
      <ExclamationCircleIcon className="mt-[2px] h-4 w-4 shrink-0 text-error" />
      <p className="flex-1 text-[13px]">{message}</p>
      <button type="button" onClick={onDismiss} aria-label="Dismiss">
        <XMarkIcon className="h-4 w-4 text-error" />
      </button>
    </div>
  );
}

// Shared visual bits for the AuthLayout pages (login, forgot-password).

import { ExclamationCircleIcon, XMarkIcon } from '@heroicons/react/24/outline';
import { cn } from '@/core/utils/cn';

export function inputCls(hasError: boolean): string {
  return cn(
    'w-full rounded-[11px] border bg-surface-2 px-[13px] py-[11px] text-[13.5px] text-ink outline-none transition-colors placeholder:text-ink-3',
    // Thicker outline on focus, no glow: drop the soft ring shadow and use a
    // real CSS outline (no layout shift) layered just outside the border.
    'focus:border-accent-line',
    hasError ? 'border-neg focus:border-neg' : 'border-line',
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
      <span className="text-[11.5px] font-semibold tracking-[0.1px] text-ink-2">{label}</span>
      {input}
      {error ? <span className="block text-[12px] text-neg">{error}</span> : null}
    </label>
  );
}

export function ErrorBanner({ message, onDismiss }: { message: string; onDismiss: () => void }) {
  return (
    <div className="flex items-start gap-tk-sm rounded-[11px] border border-neg bg-neg-soft px-[13px] py-[11px] text-neg">
      <ExclamationCircleIcon className="mt-[2px] h-4 w-4 shrink-0 text-neg" />
      <p className="flex-1 text-[13px]">{message}</p>
      <button type="button" onClick={onDismiss} aria-label="Dismiss">
        <XMarkIcon className="h-4 w-4 text-neg" />
      </button>
    </div>
  );
}

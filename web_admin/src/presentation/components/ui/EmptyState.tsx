import type { ReactNode } from 'react';

export function EmptyState({ message, action }: { message: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-11 text-center">
      <p className="text-cell text-ink-3">{message}</p>
      {action}
    </div>
  );
}

import type { ReactNode } from 'react';

/** Warns that a query result was truncated at its fetch cap. */
export function CappedNotice({ capped, children }: { capped: boolean; children: ReactNode }) {
  if (!capped) return null;
  return (
    <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
      {children}
    </p>
  );
}

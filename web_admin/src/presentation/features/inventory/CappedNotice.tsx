/** Warns that velocity is computed from a truncated sales sample. */
export function CappedNotice({ capped, cap }: { capped: boolean; cap: number }) {
  if (!capped) return null;
  return (
    <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
      Velocity is computed from the most recent {cap.toLocaleString()} sales — it may be
      understated for this window.
    </p>
  );
}

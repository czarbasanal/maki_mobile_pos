// Loading placeholder at the real content's dimensions — never a spinner
// inside a card (spec §7).
export function Skeleton({ width = '100%', height = '14px' }: { width?: string; height?: string }) {
  return <div aria-hidden className="animate-pulse rounded-chip bg-surface-3" style={{ width, height }} />;
}

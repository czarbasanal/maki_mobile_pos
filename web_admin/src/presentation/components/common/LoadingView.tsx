// Tiny SVG spinner — heroicons doesn't ship a dedicated spinner, and
// rotating ArrowPathIcon implies "refresh" semantics we don't want here.
// Inline keeps the bundle lean and the strokes consistent with Heroicons.

export function LoadingView({ label = 'Loading…' }: { label?: string }) {
  return (
    <div className="flex h-full w-full items-center justify-center gap-tk-sm p-tk-xl text-light-text-secondary">
      <Spinner />
      <span className="text-bodySmall">{label}</span>
    </div>
  );
}

export function Spinner({ className = 'h-4 w-4' }: { className?: string }) {
  return (
    <svg
      className={`animate-spin ${className}`}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeOpacity="0.2" strokeWidth="2" />
      <path
        d="M21 12a9 9 0 0 0-9-9"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}

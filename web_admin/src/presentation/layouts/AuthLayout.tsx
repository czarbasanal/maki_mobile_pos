// Bare layout for /login, /forgot-password and /access-denied — the sign-in
// guide's one centered column: the page's own block centered by `margin:
// auto` (NOT justify-center, which would drag the version row up under the
// card), v1.0.0 pinned to the bottom in mono. The theme toggle was dropped
// on the user's call — the screen follows the stored/system theme.
import { Outlet } from 'react-router-dom';

export function AuthLayout() {
  return (
    <div className="flex min-h-full w-full flex-col items-center bg-bg p-4 sm:px-6 sm:pb-8 sm:pt-7">
      <div className="my-auto w-full max-w-[392px]">
        <Outlet />
      </div>

      <span className="font-mono text-[11px] text-ink-3">v1.0.0</span>
    </div>
  );
}

// Bare layout for /login, /forgot-password and /access-denied — the sign-in
// guide's one centered column: theme toggle pinned top-right, the page's own
// block centered by `margin: auto 0` (NOT justify-center, which would drag
// the version row up under the card), v1.0.0 pinned to the bottom in mono.
import { Outlet } from 'react-router-dom';
import { MoonIcon, SunIcon } from '@heroicons/react/24/outline';
import { useTheme } from '@/core/theme/ThemeProvider';

export function AuthLayout() {
  const { theme, toggleTheme } = useTheme();
  return (
    <div className="flex min-h-full w-full flex-col items-center bg-bg p-4 pt-6 sm:px-6 sm:pb-8 sm:pt-7">
      <div className="flex w-full max-w-[392px] justify-end">
        <button
          type="button"
          title={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
          onClick={toggleTheme}
          className="flex items-center gap-[7px] rounded-ctl border border-line bg-surface px-3 py-[7px] text-ctl-sm text-ink-2 hover:border-ink-3 hover:text-ink"
        >
          {theme === 'dark' ? <SunIcon className="h-4 w-4" /> : <MoonIcon className="h-4 w-4" />}
          {theme === 'dark' ? 'Light' : 'Dark'}
        </button>
      </div>

      <div className="my-auto w-full max-w-[392px]">
        <Outlet />
      </div>

      <span className="font-mono text-[11px] text-ink-3">v1.0.0</span>
    </div>
  );
}

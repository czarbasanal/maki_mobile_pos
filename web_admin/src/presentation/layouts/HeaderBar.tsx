// Sticky per-page header: title/subtitle/primary action come from the
// active route's `handle` (screens opt in — see PageChrome below), plus the
// shared register-status readout and theme toggle that live on every page
// that has one.

import { Link, useMatches } from 'react-router-dom';
import { MoonIcon, SunIcon } from '@heroicons/react/24/outline';
import { useTheme } from '@/core/theme/ThemeProvider';
import { formatDayInt } from '@/domain/entities';
import { useRegisterStatus } from '@/presentation/hooks/useRegisterStatus';
import { Button } from '@/presentation/components/ui/Button';

export interface PageChrome {
  title: string;
  subtitle?: string;
  primaryAction?: { label: string; to: string };
  /** Screen owns its own scroll/padding — the shell skips content padding. */
  fullBleed?: boolean;
}

export function usePageChrome(): PageChrome | null {
  const matches = useMatches();
  const match = [...matches].reverse().find((m) => m.handle != null);
  return (match?.handle as PageChrome | undefined) ?? null;
}

export function HeaderBar({ chrome }: { chrome: PageChrome | null }) {
  const { theme, toggleTheme } = useTheme();
  const { open, businessDayInt } = useRegisterStatus();

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between gap-4 border-b border-line bg-surface px-7 py-[18px]">
      <div className="min-w-0">
        {chrome && <h1 className="text-page-title text-ink">{chrome.title}</h1>}
        {chrome?.subtitle && <p className="text-page-sub text-ink-2">{chrome.subtitle}</p>}
      </div>
      <div className="flex shrink-0 items-center gap-[9px]">
        <span className="pr-[3px] text-ctl-sm font-semibold text-ink">
          {formatDayInt(businessDayInt)}
        </span>
        {/* Reference header: status and the theme toggle are matching
            surface-2 boxes (1px border, 10px radius, 8x12 padding). */}
        <span className="flex items-center gap-[7px] rounded-ctl border border-line bg-surface-2 px-3 py-2 text-ctl-sm text-ink-2">
          <span aria-hidden className={`h-1.5 w-1.5 rounded-full ${open ? 'bg-pos' : 'bg-ink-3'}`} />
          {open ? 'Register open' : 'Register closed'}
        </span>
        <button
          type="button"
          title={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
          onClick={toggleTheme}
          className="flex items-center gap-[7px] rounded-ctl border border-line bg-surface-2 px-3 py-2 text-ctl-sm text-ink-2 hover:text-ink"
        >
          {theme === 'dark' ? <SunIcon className="h-4 w-4" /> : <MoonIcon className="h-4 w-4" />}
          {theme === 'dark' ? 'Light' : 'Dark'}
        </button>
        {chrome?.primaryAction && (
          <Link to={chrome.primaryAction.to}>
            <Button variant="primary">{chrome.primaryAction.label}</Button>
          </Link>
        )}
      </div>
    </header>
  );
}

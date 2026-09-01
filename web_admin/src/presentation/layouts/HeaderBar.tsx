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
import { IconButton } from '@/presentation/components/ui/IconButton';

export interface PageChrome {
  title: string;
  subtitle?: string;
  primaryAction?: { label: string; to: string };
}

export function usePageChrome(): PageChrome | null {
  const matches = useMatches();
  const match = [...matches].reverse().find((m) => m.handle != null);
  return (match?.handle as PageChrome | undefined) ?? null;
}

export function HeaderBar({ chrome }: { chrome: PageChrome }) {
  const { theme, toggleTheme } = useTheme();
  const { open, businessDayInt } = useRegisterStatus();

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between gap-4 border-b border-line bg-surface px-7 py-[18px]">
      <div className="min-w-0">
        <h1 className="text-page-title text-ink">{chrome.title}</h1>
        {chrome.subtitle && <p className="text-page-sub text-ink-2">{chrome.subtitle}</p>}
      </div>
      <div className="flex shrink-0 items-center gap-4">
        <span className="font-mono text-cell text-ink-2">{formatDayInt(businessDayInt)}</span>
        <span className="flex items-center gap-1.5 text-cell text-ink-2">
          <span aria-hidden className={`h-2 w-2 rounded-full ${open ? 'bg-pos' : 'bg-ink-3'}`} />
          {open ? 'Register open' : 'Register closed'}
        </span>
        <IconButton
          title={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
          size={28}
          onClick={toggleTheme}
        >
          {theme === 'dark' ? <SunIcon className="h-4 w-4" /> : <MoonIcon className="h-4 w-4" />}
        </IconButton>
        {chrome.primaryAction && (
          <Link to={chrome.primaryAction.to}>
            <Button variant="primary">{chrome.primaryAction.label}</Button>
          </Link>
        )}
      </div>
    </header>
  );
}

// Vercel-style admin shell. Sidebar on the left (brand + nav + account
// block), content area takes the rest. The sticky HeaderBar (business date,
// register status, theme toggle, and — when the active route has a `handle`
// — the page title/subtitle/primary action) renders on every view, sitting
// outside the scroll container so it stays fixed. A route can mark its
// handle `fullBleed` to own its own scroll/padding instead of the shell's.

import { Outlet } from 'react-router-dom';
import { Sidebar } from '@/presentation/components/common/Sidebar';
import { OfflineBanner } from '@/presentation/components/common/OfflineBanner';
import { AccountDeactivationGuard } from '@/presentation/components/common/AccountDeactivationGuard';
import { Toaster } from '@/presentation/components/ui/Toaster';
import { HeaderBar, usePageChrome } from './HeaderBar';

export function AppShell() {
  const chrome = usePageChrome();
  return (
    <div className="flex h-full w-full bg-bg">
      <Sidebar />
      <main className="flex min-w-0 flex-1 flex-col overflow-hidden">
        <OfflineBanner />
        <HeaderBar chrome={chrome} />
        <div className="flex-1 overflow-y-auto">
          <div className={chrome?.fullBleed ? undefined : 'px-7 pb-10 pt-[22px]'}>
            <Outlet />
          </div>
        </div>
      </main>
      <Toaster />
      <AccountDeactivationGuard />
    </div>
  );
}

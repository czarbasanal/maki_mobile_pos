// Vercel-style admin shell. Sidebar on the left (brand + nav + account
// block), content area takes the rest. Replaces AdminShell: adds a sticky
// per-page HeaderBar (business date, register status, theme toggle, primary
// action) for routes that opt in via a `handle` — legacy pages without one
// render no shell header and no shell padding, and keep owning their own
// headers untouched.

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
        {chrome && <HeaderBar chrome={chrome} />}
        <div className="flex-1 overflow-y-auto">
          <div className={chrome ? 'px-7 pb-10 pt-[22px]' : undefined}>
            <Outlet />
          </div>
        </div>
      </main>
      <Toaster />
      <AccountDeactivationGuard />
    </div>
  );
}

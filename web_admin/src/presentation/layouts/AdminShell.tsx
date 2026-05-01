// Vercel-style admin shell. Sidebar on the left (brand + nav + account block),
// content area takes the rest. Pages own their own headers — there's no
// top bar to fight for vertical space.

import { Outlet } from 'react-router-dom';
import { Sidebar } from '@/presentation/components/common/Sidebar';
import { OfflineBanner } from '@/presentation/components/common/OfflineBanner';

export function AdminShell() {
  return (
    <div className="flex h-full w-full bg-light-background">
      <Sidebar />
      <main className="flex flex-1 flex-col overflow-hidden">
        <OfflineBanner />
        <div className="flex-1 overflow-auto">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

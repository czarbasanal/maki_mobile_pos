// Persistent shell of the React admin app. Mirrors lib/presentation/web/layouts/web_shell.dart:
// sidebar (left), top bar with offline banner, content area constrained to
// max-content width.

import { Outlet } from 'react-router-dom';
import { Sidebar } from '@/presentation/components/common/Sidebar';
import { TopBar } from '@/presentation/components/common/TopBar';
import { OfflineBanner } from '@/presentation/components/common/OfflineBanner';
import { useUiStore } from '@/presentation/stores/uiStore';

export function AdminShell() {
  const sidebarExtended = useUiStore((s) => s.sidebarExtended);

  return (
    <div className="flex h-full w-full bg-light-background">
      <Sidebar extended={sidebarExtended} />
      <div className="flex flex-1 flex-col overflow-hidden">
        <OfflineBanner />
        <TopBar />
        <div className="flex flex-1 overflow-auto">
          <div className="mx-auto w-full max-w-content">
            <Outlet />
          </div>
        </div>
      </div>
    </div>
  );
}

// Mirror of lib/presentation/web/widgets/web_top_bar.dart: brand, search
// placeholder, user menu with sign-out.

import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronDown, LogOut, PanelLeft, Search } from 'lucide-react';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useUiStore } from '@/presentation/stores/uiStore';
import { useAuthRepo } from '@/infrastructure/di/container';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';

export function TopBar() {
  const user = useAuthStore((s) => s.user);
  const toggleSidebar = useUiStore((s) => s.toggleSidebar);

  return (
    <header className="flex h-topbar items-center gap-tk-lg border-b border-light-divider bg-light-background px-tk-lg">
      <button
        type="button"
        onClick={toggleSidebar}
        className="rounded-md p-tk-xs text-light-text-secondary hover:bg-light-surface"
        aria-label="Toggle sidebar"
      >
        <PanelLeft className="h-5 w-5" />
      </button>
      <span className="text-[15px] font-bold tracking-[0.5px] text-light-text">MAKI POS</span>
      <div className="ml-tk-md max-w-[480px] flex-1">
        <SearchPlaceholder />
      </div>
      <div className="ml-auto" />
      {user ? <UserMenu email={user.email} role={user.role} /> : null}
    </header>
  );
}

function SearchPlaceholder() {
  return (
    <div className="flex items-center gap-tk-sm rounded-md border border-light-border bg-light-surface px-tk-md py-tk-sm text-light-text-hint">
      <Search className="h-4 w-4" />
      <span className="text-bodySmall italic">Search…</span>
    </div>
  );
}

function UserMenu({ email, role }: { email: string; role: string }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();
  const authRepo = useAuthRepo();

  useEffect(() => {
    if (!open) return;
    const onClick = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, [open]);

  const onSignOut = async () => {
    await authRepo.signOut();
    navigate(RoutePaths.login, { replace: true });
  };

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex items-center gap-tk-sm rounded-md px-tk-sm py-tk-xs hover:bg-light-surface"
      >
        <span className="grid h-8 w-8 place-items-center rounded-full bg-primary-dark text-[13px] text-white">
          {email[0]?.toUpperCase() ?? '?'}
        </span>
        <span className="text-bodyMedium text-light-text">{email}</span>
        <ChevronDown className="h-4 w-4 text-light-text-secondary" />
      </button>
      <div
        className={cn(
          'absolute right-0 mt-tk-sm w-64 origin-top-right overflow-hidden rounded-md border border-light-border bg-light-card shadow-lg',
          open ? 'block' : 'hidden',
        )}
      >
        <div className="border-b border-light-divider p-tk-md">
          <div className="text-bodyMedium text-light-text">{email}</div>
          <div className="mt-tk-xs text-bodySmall uppercase tracking-[0.6px] text-light-text-secondary">
            {role}
          </div>
        </div>
        <button
          type="button"
          onClick={onSignOut}
          className="flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-bodyMedium text-light-text hover:bg-light-surface"
        >
          <LogOut className="h-4 w-4" />
          Sign out
        </button>
      </div>
    </div>
  );
}

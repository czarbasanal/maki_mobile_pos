// Vercel-style sidebar: pure white, no nav icons, items separated by
// whitespace. Account block pinned to the foot of the column.
//
// Items the active user can't reach are filtered via `canAccess` — same
// gate as the route guard, so the sidebar can't surface a route that
// would 403 on click.

import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import { useEffect, useRef, useState, type ComponentType, type SVGProps } from 'react';
import {
  ArrowRightStartOnRectangleIcon,
  BanknotesIcon,
  BuildingStorefrontIcon,
  ChartBarIcon,
  ChevronUpIcon,
  ClockIcon,
  Cog6ToothIcon,
  CubeIcon,
  PencilSquareIcon,
  ReceiptPercentIcon,
  ShoppingCartIcon,
  Squares2X2Icon,
  TruckIcon,
  UsersIcon,
} from '@heroicons/react/24/outline';
import { canAccess } from '@/presentation/router/routeGuards';
import { RoutePaths } from '@/presentation/router/routePaths';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useAuthRepo } from '@/infrastructure/di/container';
import { cn } from '@/core/utils/cn';

type IconComponent = ComponentType<SVGProps<SVGSVGElement>>;

interface NavItem {
  label: string;
  path: string;
  icon: IconComponent;
}

interface NavSection {
  label: string;
  items: NavItem[];
}

const sections: NavSection[] = [
  {
    label: 'Sell',
    items: [
      { label: 'POS', path: RoutePaths.pos, icon: ShoppingCartIcon },
      { label: 'Drafts', path: RoutePaths.drafts, icon: PencilSquareIcon },
    ],
  },
  {
    label: 'Stock',
    items: [
      { label: 'Inventory', path: RoutePaths.inventory, icon: CubeIcon },
      { label: 'Receiving', path: RoutePaths.receiving, icon: TruckIcon },
      { label: 'Suppliers', path: RoutePaths.suppliers, icon: BuildingStorefrontIcon },
    ],
  },
  {
    label: 'Money',
    items: [
      { label: 'Expenses', path: RoutePaths.expenses, icon: ReceiptPercentIcon },
      { label: 'Petty Cash', path: RoutePaths.pettyCash, icon: BanknotesIcon },
      { label: 'Reports', path: RoutePaths.reports, icon: ChartBarIcon },
    ],
  },
  {
    label: 'Admin',
    items: [
      { label: 'Users', path: RoutePaths.users, icon: UsersIcon },
      { label: 'Activity Logs', path: RoutePaths.userLogs, icon: ClockIcon },
      { label: 'Settings', path: RoutePaths.settings, icon: Cog6ToothIcon },
    ],
  },
];

function isActive(currentPath: string, itemPath: string): boolean {
  if (itemPath === RoutePaths.dashboard) return currentPath === itemPath;
  return currentPath === itemPath || currentPath.startsWith(`${itemPath}/`);
}

export function Sidebar() {
  const user = useAuthStore((s) => s.user);
  const location = useLocation();

  return (
    <aside className="flex h-full w-60 shrink-0 flex-col border-r border-light-hairline bg-light-background">
      <div className="flex h-14 items-center px-tk-lg">
        <span className="text-bodyMedium font-semibold tracking-tight text-light-text">
          MAKI POS
        </span>
      </div>

      <nav className="flex-1 overflow-y-auto px-tk-sm py-tk-sm">
        <SidebarLink
          label="Dashboard"
          path={RoutePaths.dashboard}
          icon={Squares2X2Icon}
          active={isActive(location.pathname, RoutePaths.dashboard)}
        />

        {sections.map((section) => {
          const allowed = section.items.filter((item) => canAccess(item.path, user));
          if (allowed.length === 0) return null;
          return (
            <div key={section.label} className="mt-tk-lg">
              <div className="px-tk-sm pb-tk-xs text-[11px] font-medium uppercase tracking-wider text-light-text-hint">
                {section.label}
              </div>
              {allowed.map((item) => (
                <SidebarLink
                  key={item.path}
                  label={item.label}
                  path={item.path}
                  icon={item.icon}
                  active={isActive(location.pathname, item.path)}
                />
              ))}
            </div>
          );
        })}
      </nav>

      {user ? <SidebarAccount email={user.email} role={user.role} /> : null}
    </aside>
  );
}

function SidebarLink({
  label,
  path,
  icon: Icon,
  active,
}: {
  label: string;
  path: string;
  icon: IconComponent;
  active: boolean;
}) {
  return (
    <NavLink
      to={path}
      end={path === RoutePaths.dashboard}
      className={cn(
        'flex items-center gap-tk-sm rounded-md px-tk-sm py-[6px] text-bodySmall transition-colors',
        active
          ? 'bg-light-subtle font-semibold text-light-text'
          : 'text-light-text-secondary hover:bg-light-subtle hover:text-light-text',
      )}
    >
      <Icon className="h-4 w-4 shrink-0" />
      <span className="truncate">{label}</span>
    </NavLink>
  );
}

function SidebarAccount({ email, role }: { email: string; role: string }) {
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
    setOpen(false);
    await authRepo.signOut();
    navigate(RoutePaths.login, { replace: true });
  };

  return (
    <div ref={ref} className="relative border-t border-light-hairline p-tk-sm">
      {open ? (
        <div className="absolute bottom-full left-tk-sm right-tk-sm mb-tk-xs overflow-hidden rounded-md border border-light-hairline bg-light-card shadow-lg">
          <div className="border-b border-light-hairline px-tk-md py-tk-sm">
            <div className="truncate text-bodySmall text-light-text">{email}</div>
            <div className="mt-[2px] text-[11px] uppercase tracking-wider text-light-text-hint">
              {role}
            </div>
          </div>
          <button
            type="button"
            onClick={onSignOut}
            className="flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <ArrowRightStartOnRectangleIcon className="h-4 w-4" />
            Sign out
          </button>
        </div>
      ) : null}
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center gap-tk-sm rounded-md px-tk-sm py-tk-sm text-left transition-colors hover:bg-light-subtle"
      >
        <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-primary-dark text-[12px] font-medium text-white">
          {email[0]?.toUpperCase() ?? '?'}
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-bodySmall text-light-text">{email}</span>
          <span className="block text-[11px] uppercase tracking-wider text-light-text-hint">
            {role}
          </span>
        </span>
        <ChevronUpIcon
          className={cn(
            'h-4 w-4 shrink-0 text-light-text-secondary transition-transform',
            open ? 'rotate-180' : '',
          )}
        />
      </button>
    </div>
  );
}

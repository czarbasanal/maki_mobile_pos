// Mirror of lib/presentation/web/widgets/web_sidebar.dart: persistent, grouped,
// role-aware. Items the active user can't reach are filtered out via the same
// `canAccess` check used by the route guard.

import { NavLink, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Settings as SettingsIcon,
  Users,
  History,
  ShoppingCart,
  FileEdit,
  Package,
  Truck,
  Building2,
  ReceiptText,
  PiggyBank,
  BarChart3,
  type LucideIcon,
} from 'lucide-react';
import { canAccess } from '@/presentation/router/routeGuards';
import { RoutePaths } from '@/presentation/router/routePaths';
import { useAuthStore } from '@/presentation/stores/authStore';
import { cn } from '@/core/utils/cn';

interface NavItem {
  icon: LucideIcon;
  label: string;
  path: string;
}

interface NavSection {
  label: string;
  items: NavItem[];
}

const sections: NavSection[] = [
  {
    label: 'Sell',
    items: [
      { icon: ShoppingCart, label: 'POS', path: RoutePaths.pos },
      { icon: FileEdit, label: 'Drafts', path: RoutePaths.drafts },
    ],
  },
  {
    label: 'Stock',
    items: [
      { icon: Package, label: 'Inventory', path: RoutePaths.inventory },
      { icon: Truck, label: 'Receiving', path: RoutePaths.receiving },
      { icon: Building2, label: 'Suppliers', path: RoutePaths.suppliers },
    ],
  },
  {
    label: 'Money',
    items: [
      { icon: ReceiptText, label: 'Expenses', path: RoutePaths.expenses },
      { icon: PiggyBank, label: 'Petty Cash', path: RoutePaths.pettyCash },
      { icon: BarChart3, label: 'Reports', path: RoutePaths.reports },
    ],
  },
  {
    label: 'Admin',
    items: [
      { icon: Users, label: 'Users', path: RoutePaths.users },
      { icon: History, label: 'Activity Logs', path: RoutePaths.userLogs },
      { icon: SettingsIcon, label: 'Settings', path: RoutePaths.settings },
    ],
  },
];

function isActive(currentPath: string, itemPath: string): boolean {
  if (itemPath === RoutePaths.dashboard) return currentPath === itemPath;
  return currentPath === itemPath || currentPath.startsWith(`${itemPath}/`);
}

export function Sidebar({ extended }: { extended: boolean }) {
  const user = useAuthStore((s) => s.user);
  const location = useLocation();

  return (
    <aside
      className={cn(
        'flex h-full shrink-0 flex-col border-r border-light-divider bg-light-surface transition-all',
        extended ? 'w-sidebar-extended' : 'w-sidebar-collapsed',
      )}
    >
      <div className="pt-tk-md">
        <SidebarItem
          icon={LayoutDashboard}
          label="Dashboard"
          path={RoutePaths.dashboard}
          extended={extended}
          active={isActive(location.pathname, RoutePaths.dashboard)}
        />
      </div>
      <nav className="flex-1 overflow-y-auto py-tk-sm">
        {sections.map((section) => {
          const allowed = section.items.filter((item) => canAccess(item.path, user));
          if (allowed.length === 0) return null;
          return (
            <div key={section.label} className="mt-tk-sm">
              {extended ? (
                <div className="px-tk-lg pb-tk-xs pt-tk-md text-[11px] font-semibold uppercase tracking-[1.2px] text-light-text-secondary">
                  {section.label}
                </div>
              ) : (
                <div className="my-tk-sm border-t border-light-divider" />
              )}
              {allowed.map((item) => (
                <SidebarItem
                  key={item.path}
                  icon={item.icon}
                  label={item.label}
                  path={item.path}
                  extended={extended}
                  active={isActive(location.pathname, item.path)}
                />
              ))}
            </div>
          );
        })}
      </nav>
    </aside>
  );
}

function SidebarItem({
  icon: Icon,
  label,
  path,
  extended,
  active,
}: {
  icon: LucideIcon;
  label: string;
  path: string;
  extended: boolean;
  active: boolean;
}) {
  return (
    <div className="px-tk-sm py-[2px]">
      <NavLink
        to={path}
        className={cn(
          'flex items-center gap-tk-md rounded-md px-tk-md py-[10px] transition-colors',
          active
            ? 'bg-primary-accent/[0.18] text-primary-dark'
            : 'text-light-text-secondary hover:bg-light-divider/40 hover:text-light-text',
        )}
        end={path === RoutePaths.dashboard}
      >
        <Icon className="h-5 w-5 shrink-0" />
        {extended ? (
          <span className={cn('truncate text-bodySmall', active ? 'font-semibold' : 'font-medium')}>
            {label}
          </span>
        ) : null}
      </NavLink>
    </div>
  );
}

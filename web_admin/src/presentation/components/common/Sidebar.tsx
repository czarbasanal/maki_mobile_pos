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
  BellAlertIcon,
  BriefcaseIcon,
  BuildingStorefrontIcon,
  CalendarDaysIcon,
  ChartBarIcon,
  ChevronDoubleLeftIcon,
  ChevronDoubleRightIcon,
  ChevronDownIcon,
  ChevronUpIcon,
  ClipboardDocumentListIcon,
  ClockIcon,
  Cog6ToothIcon,
  CubeIcon,
  DocumentTextIcon,
  IdentificationIcon,
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
import { useSignOut } from '@/presentation/hooks/useSignOut';
import { useVoidRequests } from '@/presentation/hooks/useVoidRequests';
import { cn } from '@/core/utils/cn';

type IconComponent = ComponentType<SVGProps<SVGSVGElement>>;

interface NavItem {
  label: string;
  path: string;
  icon: IconComponent;
  /** Sub-items rendered as an expandable group under this item. */
  children?: NavItem[];
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
      { label: 'Job Orders', path: RoutePaths.jobOrders, icon: PencilSquareIcon },
    ],
  },
  {
    label: 'Stock',
    items: [
      {
        label: 'Inventory',
        path: RoutePaths.inventory,
        icon: CubeIcon,
      },
      // Price History reads across the whole catalogue rather than drilling
      // into one product, so it stands on its own rather than nesting under
      // Inventory.
      { label: 'Price History', path: RoutePaths.priceHistory, icon: ClockIcon },
      // Receiving is the dashboard at /receiving; New Receiving and Import CSV
      // (bulk) are actions inside it, so they have no standalone nav entries.
      { label: 'Receiving', path: RoutePaths.receiving, icon: TruckIcon },
      // Reorder suggestions live inside a purchase order now — the question
      // "what should I buy" is answered by starting the buying list.
      { label: 'Purchase Orders', path: RoutePaths.purchaseOrders, icon: ClipboardDocumentListIcon },
      { label: 'Suppliers', path: RoutePaths.suppliers, icon: BuildingStorefrontIcon },
    ],
  },
  {
    label: 'Money',
    items: [
      { label: 'Expenses', path: RoutePaths.expenses, icon: ReceiptPercentIcon },
      { label: 'Reports', path: RoutePaths.reports, icon: ChartBarIcon },
    ],
  },
  {
    label: 'Admin',
    items: [
      { label: 'Void Requests', path: RoutePaths.voidRequests, icon: BellAlertIcon },
      { label: 'Users', path: RoutePaths.users, icon: UsersIcon },
      { label: 'Activity Logs', path: RoutePaths.userLogs, icon: ClockIcon },
      {
        // The header link lands on Employees via the /hr redirect.
        label: 'HR',
        path: RoutePaths.hr,
        icon: BriefcaseIcon,
        children: [
          { label: 'Employees', path: RoutePaths.hrEmployees, icon: IdentificationIcon },
          { label: 'Payroll', path: RoutePaths.hrPayroll, icon: BanknotesIcon },
          { label: 'Payslips', path: RoutePaths.hrPayslips, icon: DocumentTextIcon },
          { label: 'HR Settings', path: RoutePaths.hrSettings, icon: CalendarDaysIcon },
        ],
      },
      { label: 'Settings', path: RoutePaths.settings, icon: Cog6ToothIcon },
    ],
  },
];

// Tablets (and anything narrower than a desktop monitor) start collapsed;
// the toggle overrides either way for the rest of the session.
const TABLET_QUERY = '(max-width: 1279px)';

function useTabletViewport(): boolean {
  const [isTablet, setIsTablet] = useState(
    () => window.matchMedia?.(TABLET_QUERY).matches ?? false,
  );
  useEffect(() => {
    const mql = window.matchMedia?.(TABLET_QUERY);
    if (!mql) return;
    const onChange = (e: MediaQueryListEvent) => setIsTablet(e.matches);
    mql.addEventListener('change', onChange);
    return () => mql.removeEventListener('change', onChange);
  }, []);
  return isTablet;
}

function isActive(currentPath: string, itemPath: string): boolean {
  if (itemPath === RoutePaths.dashboard) return currentPath === itemPath;
  return currentPath === itemPath || currentPath.startsWith(`${itemPath}/`);
}

export function Sidebar() {
  const user = useAuthStore((s) => s.user);
  const location = useLocation();
  const isTablet = useTabletViewport();
  const [manualCollapsed, setManualCollapsed] = useState<boolean | null>(null);
  const collapsed = manualCollapsed ?? isTablet;
  // Only admins can reach the queue, and canAccess already filters the item
  // out for everyone else — but the subscription would still run, so gate it.
  const canSeeVoids = !!user && canAccess(RoutePaths.voidRequests, user);
  const { pending } = useVoidRequests();
  const pendingVoids = canSeeVoids ? pending.length : 0;

  return (
    <aside
      className={cn(
        'flex h-full shrink-0 flex-col border-r border-light-hairline bg-light-background transition-all duration-200',
        collapsed ? 'w-14' : 'w-60',
      )}
    >
      <div
        className={cn(
          'flex h-14 items-center',
          collapsed ? 'justify-center' : 'justify-between px-tk-lg',
        )}
      >
        {collapsed ? null : (
          <span className="text-bodyMedium font-semibold tracking-tight text-light-text">
            MAKI POS
          </span>
        )}
        <button
          type="button"
          onClick={() => setManualCollapsed(!collapsed)}
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          className="rounded-md p-tk-xs text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
        >
          {collapsed ? (
            <ChevronDoubleRightIcon className="h-4 w-4" />
          ) : (
            <ChevronDoubleLeftIcon className="h-4 w-4" />
          )}
        </button>
      </div>

      <nav className="flex-1 overflow-y-auto px-tk-sm py-tk-sm">
        <SidebarLink
          label="Dashboard"
          path={RoutePaths.dashboard}
          icon={Squares2X2Icon}
          active={isActive(location.pathname, RoutePaths.dashboard)}
          collapsed={collapsed}
        />

        {sections.map((section) => {
          const allowed = section.items.filter((item) => canAccess(item.path, user));
          if (allowed.length === 0) return null;
          return (
            <div key={section.label} className={collapsed ? 'mt-tk-sm' : 'mt-tk-lg'}>
              {collapsed ? (
                <div className="mx-tk-xs mb-tk-sm border-t border-light-hairline" />
              ) : (
                <div className="px-tk-sm pb-tk-xs text-[11px] font-medium uppercase tracking-wider text-light-text-hint">
                  {section.label}
                </div>
              )}
              {allowed.map((item) => {
                const children = (item.children ?? []).filter((c) =>
                  canAccess(c.path, user),
                );
                if (!collapsed && children.length > 0) {
                  return (
                    <SidebarGroup
                      key={item.path}
                      item={item}
                      childItems={children}
                      currentPath={location.pathname}
                    />
                  );
                }
                return (
                  <SidebarLink
                    key={item.path}
                    label={item.label}
                    path={item.path}
                    icon={item.icon}
                    active={isActive(location.pathname, item.path)}
                    collapsed={collapsed}
                    badge={
                      item.path === RoutePaths.voidRequests ? pendingVoids : 0
                    }
                  />
                );
              })}
            </div>
          );
        })}
      </nav>

      {user ? (
        <SidebarAccount email={user.email} role={user.role} collapsed={collapsed} />
      ) : null}
    </aside>
  );
}

function SidebarGroup({
  item,
  childItems,
  currentPath,
}: {
  item: NavItem;
  childItems: NavItem[];
  currentPath: string;
}) {
  // Auto-open anywhere in the subtree, but the chevron always wins — the
  // override clears on every navigation so the next page re-derives it.
  const inSubtree = isActive(currentPath, item.path);
  const [manualOpen, setManualOpen] = useState<boolean | null>(null);
  useEffect(() => setManualOpen(null), [currentPath]);
  const open = manualOpen ?? inSubtree;
  const childActive = childItems.some((c) => isActive(currentPath, c.path));

  return (
    <div>
      <div className="flex items-center">
        <div className="min-w-0 flex-1">
          <SidebarLink
            label={item.label}
            path={item.path}
            icon={item.icon}
            active={inSubtree && !childActive}
          />
        </div>
        <button
          type="button"
          onClick={() => setManualOpen(!open)}
          aria-label={`${open ? 'Collapse' : 'Expand'} ${item.label}`}
          className="rounded-md p-tk-xs text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
        >
          <ChevronDownIcon
            className={cn('h-3.5 w-3.5 transition-transform', open ? 'rotate-180' : '')}
          />
        </button>
      </div>
      {open ? (
        <div className="ml-[15px] border-l border-light-hairline pl-tk-xs">
          {childItems.map((child) => (
            <SidebarLink
              key={child.path}
              label={child.label}
              path={child.path}
              icon={child.icon}
              active={isActive(currentPath, child.path)}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}

function SidebarLink({
  label,
  path,
  icon: Icon,
  active,
  collapsed = false,
  badge = 0,
}: {
  label: string;
  path: string;
  icon: IconComponent;
  active: boolean;
  collapsed?: boolean;
  /** Count shown as a pill; 0 renders nothing. */
  badge?: number;
}) {
  return (
    <NavLink
      to={path}
      end={path === RoutePaths.dashboard}
      aria-label={label}
      title={collapsed ? label : undefined}
      className={cn(
        'relative flex items-center rounded-md text-bodySmall transition-colors',
        collapsed ? 'justify-center py-[8px]' : 'gap-tk-sm px-tk-sm py-[6px]',
        active
          ? 'bg-light-subtle font-semibold text-light-text'
          : 'text-light-text-secondary hover:bg-light-subtle hover:text-light-text',
      )}
    >
      <Icon className="h-4 w-4 shrink-0" />
      {collapsed ? null : <span className="truncate">{label}</span>}
      {badge > 0 ? (
        <span
          className={cn(
            'flex h-4 min-w-[16px] items-center justify-center rounded-full bg-error px-[4px] text-[10px] font-semibold leading-none text-white',
            // Collapsed: the label is gone, so pin the count to the icon
            // rather than letting it push the row wider than the rail.
            collapsed ? 'absolute right-1 top-1' : 'ml-auto',
          )}
        >
          {badge}
        </span>
      ) : null}
    </NavLink>
  );
}

function SidebarAccount({
  email,
  role,
  collapsed = false,
}: {
  email: string;
  role: string;
  collapsed?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();
  const signOut = useSignOut();

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
    await signOut.mutateAsync();
    navigate(RoutePaths.login, { replace: true });
  };

  return (
    <div ref={ref} className="relative border-t border-light-hairline p-tk-sm">
      {open ? (
        <div
          className={cn(
            'absolute bottom-full left-tk-sm z-20 mb-tk-xs overflow-hidden rounded-md border border-light-hairline bg-light-card shadow-lg',
            collapsed ? 'w-56' : 'right-tk-sm',
          )}
        >
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
        aria-label="Account menu"
        title={collapsed ? email : undefined}
        className={cn(
          'flex w-full items-center rounded-md text-left transition-colors hover:bg-light-subtle',
          collapsed ? 'justify-center py-tk-sm' : 'gap-tk-sm px-tk-sm py-tk-sm',
        )}
      >
        <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-primary-dark text-[12px] font-medium text-white">
          {email[0]?.toUpperCase() ?? '?'}
        </span>
        {collapsed ? null : (
          <>
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
          </>
        )}
      </button>
    </div>
  );
}

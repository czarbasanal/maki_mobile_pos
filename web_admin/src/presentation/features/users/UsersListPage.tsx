// Users — per design/maki-pos-users-redesign. Summary row (Accounts by role
// card whose rows filter · three sign-in KPIs), then the views row (role
// chips · Active/Inactive/All · + Add user), the filters row (search · clear
// · count), then the table card. A row (or Manage) opens the add/manage modal
// as a child route over this list. ONE subscription (every account, active
// or not) feeds the card, the KPIs, the chip counts and the table.
import { useEffect, useMemo, useState } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import { PlusIcon } from '@heroicons/react/24/outline';
import { useUsers } from '@/presentation/hooks/useUsers';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useNow } from '@/presentation/hooks/useNow';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { RoutePaths } from '@/presentation/router/routePaths';
import { UserRole, userRoleDisplayName } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { roleScope, signInStaleness, summarizeUsers } from '@/domain/users/userSignIn';
import { formatInShopZone, formatShopDateTime } from '@/domain/time/shopTime';
import { cn } from '@/core/utils/cn';
import { StatCard } from '@/presentation/components/ui/StatCard';
import { BreakdownCard } from '@/presentation/components/ui/BreakdownCard';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { Button } from '@/presentation/components/ui/Button';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { ViewChips } from '@/presentation/components/ui/ViewChips';
import { Segmented } from '@/presentation/components/ui/Segmented';
import { NoMatchesState } from '@/presentation/components/ui/TableEmptyStates';
import { TableFooter } from '@/presentation/components/ui/TableFooter';
import { ErrorState } from '@/presentation/components/ui/ErrorState';
import { RoleBadge, roleColor } from './RoleBadge';

type StatusFilter = 'active' | 'inactive' | 'all';
type RoleFilter = UserRole | 'all';
const ROLES: UserRole[] = [UserRole.admin, UserRole.staff, UserRole.cashier];

const staleCls = { 'ink-3': 'text-ink-3', 'accent-text': 'text-accent-text', neg: 'text-neg' } as const;

export function UsersListPage() {
  const navigate = useNavigate();
  const me = useAuthStore((s) => s.user);
  const now = useNow();
  const { data, isLoading, error } = useUsers(true);
  const users = useMemo(() => data ?? [], [data]);

  const [status, setStatus] = useState<StatusFilter>('active');
  const [role, setRole] = useState<RoleFilter>('all');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('users');

  useEffect(() => {
    document.title = 'Users · MAKI POS Admin';
  }, []);
  useEffect(() => {
    setPage(1);
  }, [status, role, query]);

  const summary = useMemo(() => summarizeUsers(users, now), [users, now]);

  // Status + search scope the set the chip counts read; only the table
  // narrows further by role — or the chips contradict the rows.
  const scoped = useMemo(() => {
    const q = query.trim().toLowerCase();
    return users.filter((u) => {
      if (status === 'active' && !u.isActive) return false;
      if (status === 'inactive' && u.isActive) return false;
      if (!q) return true;
      return u.displayName.toLowerCase().includes(q) || u.email.toLowerCase().includes(q);
    });
  }, [users, status, query]);
  const rows = useMemo(
    () =>
      scoped
        .filter((u) => role === 'all' || u.role === role)
        .sort((a, b) => (a.isActive !== b.isActive ? (a.isActive ? -1 : 1) : a.displayName.localeCompare(b.displayName))),
    [scoped, role],
  );
  usePageClamp(page, setPage, rows.length, pageSize);
  const paged = useMemo(() => rows.slice((page - 1) * pageSize, page * pageSize), [rows, page, pageSize]);

  const isFiltered = role !== 'all' || query.trim() !== '';
  const clearFilters = () => {
    setRole('all');
    setQuery('');
  };

  const columns: Array<Column<User>> = [
    {
      // Fixed so it can't balloon on wide screens; name and email truncate.
      key: 'user', header: 'User', width: '300px',
      render: (u) => {
        const c = roleColor[u.role];
        return (
          <div className="flex min-w-0 items-center gap-3">
            <div
              className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-ctl border"
              style={{ background: c.soft, borderColor: c.fill }}
            >
              <span className="font-mono text-[13px] font-semibold" style={{ color: c.text }}>
                {(u.displayName || u.email).charAt(0).toUpperCase()}
              </span>
            </div>
            <div className="flex min-w-0 flex-col gap-0.5">
              <div className="flex min-w-0 items-center gap-[7px]">
                <span className="truncate text-[13px] font-semibold tracking-[-0.15px] text-ink">{u.displayName || '—'}</span>
                {me && u.id === me.id ? (
                  <span className="rounded-[5px] bg-accent-soft px-1.5 py-[2px] text-[9.5px] font-bold tracking-[0.8px] text-accent-text">YOU</span>
                ) : null}
              </div>
              <span className="truncate text-[11.5px] text-ink-3">{u.email}</span>
            </div>
          </div>
        );
      },
    },
    { key: 'role', header: 'Role', width: '110px', render: (u) => <RoleBadge role={u.role} /> },
    {
      // No fixed width: this column absorbs the slack, and its two lines never wrap.
      key: 'seen', header: 'Last sign-in',
      render: (u) => {
        const s = signInStaleness(u.lastLoginAt, now);
        return (
          <div className="flex flex-col gap-0.5 whitespace-nowrap">
            <span className="font-mono text-[12px] text-ink-2">{u.lastLoginAt ? formatShopDateTime(u.lastLoginAt) : 'Never'}</span>
            <span className={cn('text-[10.5px]', staleCls[s.tone])}>{s.label}</span>
          </div>
        );
      },
    },
    {
      key: 'added', header: 'Added', width: '118px', mono: true,
      render: (u) => <span className="whitespace-nowrap text-[11.5px] text-ink-3">{formatInShopZone(u.createdAt, { month: 'short', day: 'numeric', year: 'numeric' })}</span>,
    },
    {
      key: 'status', header: 'Status', width: '104px',
      render: (u) => (
        <span className={cn('flex items-center gap-1.5 text-[12px] font-medium', u.isActive ? 'text-pos' : 'text-ink-3')}>
          <span className={cn('h-1.5 w-1.5 rounded-full', u.isActive ? 'bg-pos' : 'bg-ink-3')} />
          {u.isActive ? 'Active' : 'Inactive'}
        </span>
      ),
    },
    {
      key: 'manage', header: '', width: '96px',
      render: (u) => (
        <div className="flex justify-end">
          <Button variant="secondary" size="sm" onClick={(e) => { e.stopPropagation(); navigate(`/users/edit/${u.id}`); }}>
            Manage
          </Button>
        </div>
      ),
    },
  ];

  if (error) return <ErrorState message="Could not load users." onRetry={() => window.location.reload()} />;

  return (
    <div className="flex flex-col gap-3">
      {/* Summary row */}
      <div className="grid grid-cols-[repeat(auto-fit,minmax(236px,1fr))] gap-3">
        <BreakdownCard
          testId="accounts-by-role"
          label="Accounts by role"
          total={`${summary.active} active`}
          bar={ROLES.map((r) => ({ key: r, color: roleColor[r].fill, pct: summary.active ? (summary.byRole[r] / summary.active) * 100 : 0 }))}
          rows={ROLES.map((r) => ({
            key: r,
            label: userRoleDisplayName[r],
            color: roleColor[r].fill,
            active: role === r,
            onClick: () => setRole(role === r ? 'all' : r),
            value: (
              <>
                <span className="text-[10.5px] text-ink-3">{roleScope[r].can}</span>
                <span className="w-5 text-right font-mono text-[13px] font-semibold text-ink">{summary.byRole[r]}</span>
              </>
            ),
          }))}
        />
        <StatCard label="Signed in this week" value={summary.signedInThisWeek} format="number" loading={isLoading}
          note={`of ${summary.active} active ${summary.active === 1 ? 'account' : 'accounts'}`} />
        <StatCard label="Dormant 30+ days" value={summary.dormant30} format="number" loading={isLoading}
          valueTone={summary.dormant30 ? 'neg' : 'pos'}
          note={summary.dormant30 ? 'review whether they still need access' : 'everyone is current'} />
        <StatCard label="Never signed in" value={summary.neverSignedIn} format="number" loading={isLoading}
          note={summary.neverSignedIn ? 'invite may not have been opened' : 'all invites accepted'} />
      </div>

      {/* Views row */}
      <div className="flex flex-wrap items-center gap-2">
        <ViewChips
          value={role}
          onChange={setRole}
          options={[
            { value: 'all' as RoleFilter, label: 'All roles', count: scoped.length },
            ...ROLES.map((r) => ({ value: r as RoleFilter, label: userRoleDisplayName[r], count: scoped.filter((u) => u.role === r).length })),
          ]}
        />
        <div className="ml-auto flex items-center gap-[9px]">
          <Segmented
            label="Status"
            value={status}
            onChange={setStatus}
            options={[
              { value: 'active', label: 'Active' },
              { value: 'inactive', label: 'Inactive' },
              { value: 'all', label: 'All' },
            ]}
          />
          <Button variant="primary" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={() => navigate(RoutePaths.userAdd)}>
            Add user
          </Button>
        </div>
      </div>

      {/* Filters row */}
      <div className="flex flex-wrap items-center gap-2.5">
        <div className="w-[290px]">
          <SearchInput variant="bar" value={query} onChange={setQuery} placeholder="Search name or email" />
        </div>
        {isFiltered ? (
          <button type="button" onClick={clearFilters} className="border-b border-line text-[11.5px] text-ink-3 hover:text-neg">
            Clear filters
          </button>
        ) : null}
        <span className="ml-auto font-mono text-[12px] text-ink-3">
          {rows.length.toLocaleString('en-PH')} {rows.length === 1 ? 'account' : 'accounts'}
        </span>
      </div>

      {/* Table card */}
      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        <DataTable
          columns={columns}
          rows={paged}
          rowKey={(u) => u.id}
          onRowClick={(u) => navigate(`/users/edit/${u.id}`)}
          rowClassName={(u) => (u.isActive ? undefined : 'opacity-[.62]')}
          loading={isLoading}
          minWidth="940px"
          empty={
            isFiltered ? (
              <NoMatchesState
                title="No users match these filters"
                hint="Try another role, or clear the search."
                onClear={clearFilters}
              />
            ) : (
              <NoMatchesState
                title={status === 'inactive' ? 'No inactive accounts' : 'No accounts yet'}
                hint={status === 'inactive' ? 'Everyone can sign in. Switch to Active or All to see them.' : 'Add a user to get started.'}
              />
            )
          }
        />
        {rows.length > 0 && !isLoading ? (
          <TableFooter total={rows.length} page={page} pageSize={pageSize} onPage={setPage}
            onPageSize={(n) => { setPageSize(n); setPage(1); }} />
        ) : null}
      </section>

      {/* /users/add and /users/edit/:id render the modal here, over the list. */}
      <Outlet />
    </div>
  );
}

// /admin/users — admin user management. Mirrors the Flutter users_screen:
// summary tiles, role filter, show-inactive toggle, table with row actions
// (edit / deactivate / reactivate).

import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  EllipsisHorizontalIcon,
  EyeIcon,
  EyeSlashIcon,
  PencilIcon,
  PlusIcon,
  UserIcon,
  UserMinusIcon,
  UserPlusIcon,
} from '@heroicons/react/24/outline';
import { useUsers } from '@/presentation/hooks/useUsers';
import {
  useDeactivateUser,
  useReactivateUser,
} from '@/presentation/hooks/useUserMutations';
import { useAuthStore } from '@/presentation/stores/authStore';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import { Spinner } from '@/presentation/components/common/LoadingView';
import { RoutePaths } from '@/presentation/router/routePaths';
import { UserRole, userRoleDisplayName } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { RoleBadge } from './RoleBadge';
import { cn } from '@/core/utils/cn';

export function UsersListPage() {
  const navigate = useNavigate();
  const me = useAuthStore((s) => s.user);
  const [showInactive, setShowInactive] = useState(false);
  const [roleFilter, setRoleFilter] = useState<UserRole | null>(null);

  const { data: users, isLoading, error } = useUsers(showInactive);

  useEffect(() => {
    document.title = 'Users · MAKI POS Admin';
  }, []);

  const filtered = useMemo(() => {
    if (!users) return [];
    let out = users;
    if (roleFilter) out = out.filter((u) => u.role === roleFilter);
    out = [...out].sort((a, b) => {
      if (a.isActive !== b.isActive) return a.isActive ? -1 : 1;
      return a.displayName.localeCompare(b.displayName);
    });
    return out;
  }, [users, roleFilter]);

  const summary = useMemo(() => {
    if (!users) return { total: 0, admin: 0, staff: 0, cashier: 0 };
    const active = users.filter((u) => u.isActive);
    return {
      total: active.length,
      admin: active.filter((u) => u.role === UserRole.admin).length,
      staff: active.filter((u) => u.role === UserRole.staff).length,
      cashier: active.filter((u) => u.role === UserRole.cashier).length,
    };
  }, [users]);

  if (error) return <ErrorView title="Could not load users" message={error.message} />;

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Users
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Add, edit, and manage admin users and staff accounts.
          </p>
        </div>
        <button
          type="button"
          onClick={() => navigate(RoutePaths.userAdd)}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
        >
          <PlusIcon className="h-3.5 w-3.5" />
          Add user
        </button>
      </header>

      <div className="grid grid-cols-2 gap-tk-md sm:grid-cols-4">
        <SummaryTile label="Total active" value={summary.total} active={roleFilter === null} onClick={() => setRoleFilter(null)} />
        <SummaryTile label="Admins" value={summary.admin} active={roleFilter === UserRole.admin} onClick={() => setRoleFilter(UserRole.admin)} />
        <SummaryTile label="Staff" value={summary.staff} active={roleFilter === UserRole.staff} onClick={() => setRoleFilter(UserRole.staff)} />
        <SummaryTile label="Cashiers" value={summary.cashier} active={roleFilter === UserRole.cashier} onClick={() => setRoleFilter(UserRole.cashier)} />
      </div>

      <div className="flex flex-wrap items-center gap-tk-sm">
        {roleFilter ? (
          <button
            type="button"
            onClick={() => setRoleFilter(null)}
            className="inline-flex items-center gap-tk-xs rounded-full bg-light-subtle px-tk-sm py-[2px] text-bodySmall text-light-text"
          >
            {userRoleDisplayName[roleFilter]}
            <span aria-hidden>×</span>
          </button>
        ) : null}
        <button
          type="button"
          onClick={() => setShowInactive((v) => !v)}
          className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-[4px] text-bodySmall text-light-text hover:bg-light-subtle"
        >
          {showInactive ? (
            <EyeSlashIcon className="h-3.5 w-3.5" />
          ) : (
            <EyeIcon className="h-3.5 w-3.5" />
          )}
          {showInactive ? 'Hide inactive' : 'Show inactive'}
        </button>
      </div>

      {isLoading || !users ? (
        <LoadingView label="Loading users…" />
      ) : filtered.length === 0 ? (
        <EmptyState title="No users found" description="Try clearing the filter or adding a new user." />
      ) : (
        <UsersTable users={filtered} myId={me?.id ?? ''} />
      )}
    </div>
  );
}

function SummaryTile({
  label,
  value,
  active,
  onClick,
}: {
  label: string;
  value: number;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'flex flex-col items-start rounded-lg border p-tk-md text-left transition-colors',
        active
          ? 'border-light-text bg-light-subtle'
          : 'border-light-hairline bg-light-card hover:bg-light-subtle',
      )}
    >
      <span className="text-bodySmall text-light-text-secondary">{label}</span>
      <span className="mt-tk-xs text-headingSmall font-semibold tabular-nums text-light-text">
        {value}
      </span>
    </button>
  );
}

function UsersTable({ users, myId }: { users: User[]; myId: string }) {
  const deactivate = useDeactivateUser();
  const reactivate = useReactivateUser();
  const [confirm, setConfirm] = useState<null | { user: User; mode: 'deactivate' | 'reactivate' }>(null);

  const onConfirm = async () => {
    if (!confirm) return;
    if (confirm.mode === 'deactivate') {
      await deactivate.mutateAsync(confirm.user);
    } else {
      await reactivate.mutateAsync(confirm.user);
    }
    setConfirm(null);
  };

  return (
    <>
      <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <Th>User</Th>
              <Th>Role</Th>
              <Th>Last sign-in</Th>
              <Th>Status</Th>
              <Th className="text-right">Actions</Th>
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {users.map((user) => (
              <UserRow
                key={user.id}
                user={user}
                isMe={user.id === myId}
                onDeactivate={() => setConfirm({ user, mode: 'deactivate' })}
                onReactivate={() => setConfirm({ user, mode: 'reactivate' })}
              />
            ))}
          </tbody>
        </table>
      </div>

      <Dialog
        open={confirm !== null}
        onClose={() => {
          if (deactivate.isPending || reactivate.isPending) return;
          setConfirm(null);
          deactivate.reset();
          reactivate.reset();
        }}
        title={confirm?.mode === 'deactivate' ? 'Deactivate user' : 'Reactivate user'}
        description={
          confirm
            ? confirm.mode === 'deactivate'
              ? `${confirm.user.displayName || confirm.user.email} will no longer be able to sign in.`
              : `${confirm.user.displayName || confirm.user.email} will be able to sign in again.`
            : undefined
        }
        dismissable={!deactivate.isPending && !reactivate.isPending}
      >
        {(deactivate.error || reactivate.error) ? (
          <p className="mb-tk-md text-bodySmall text-error">
            {(deactivate.error ?? reactivate.error)!.message}
          </p>
        ) : null}
        <div className="flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setConfirm(null)}
            disabled={deactivate.isPending || reactivate.isPending}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={deactivate.isPending || reactivate.isPending}
            className={cn(
              'flex items-center gap-tk-xs rounded-md px-tk-md py-tk-sm text-bodySmall font-semibold disabled:opacity-60',
              confirm?.mode === 'deactivate'
                ? 'bg-error text-white hover:bg-error-dark'
                : 'bg-light-text text-light-background hover:bg-primary-dark',
            )}
          >
            {(deactivate.isPending || reactivate.isPending) ? <Spinner className="h-3.5 w-3.5" /> : null}
            {confirm?.mode === 'deactivate' ? 'Deactivate' : 'Reactivate'}
          </button>
        </div>
      </Dialog>
    </>
  );
}

function Th({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <th className={cn('px-tk-md py-tk-sm text-left text-[11px] font-semibold uppercase tracking-wider', className)}>
      {children}
    </th>
  );
}

const dateFmt = new Intl.DateTimeFormat('en-PH', {
  dateStyle: 'medium',
  timeStyle: 'short',
});

function UserRow({
  user,
  isMe,
  onDeactivate,
  onReactivate,
}: {
  user: User;
  isMe: boolean;
  onDeactivate: () => void;
  onReactivate: () => void;
}) {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <tr className={cn(!user.isActive && 'opacity-60')}>
      <td className="px-tk-md py-tk-sm">
        <div className="flex items-center gap-tk-sm">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-primary-dark text-[12px] font-semibold text-white">
            {(user.displayName || user.email)[0]?.toUpperCase() ?? '?'}
          </span>
          <div className="min-w-0">
            <div className="flex items-center gap-tk-xs text-bodyMedium font-medium text-light-text">
              <span className="truncate">{user.displayName || '—'}</span>
              {isMe ? (
                <span className="rounded-full bg-light-subtle px-tk-xs py-[1px] text-[10px] uppercase tracking-wider text-light-text-secondary">
                  You
                </span>
              ) : null}
            </div>
            <div className="truncate text-[12px] text-light-text-secondary">{user.email}</div>
          </div>
        </div>
      </td>
      <td className="px-tk-md py-tk-sm">
        <RoleBadge role={user.role} />
      </td>
      <td className="px-tk-md py-tk-sm text-[12px] text-light-text-secondary">
        {user.lastLoginAt ? dateFmt.format(user.lastLoginAt) : '—'}
      </td>
      <td className="px-tk-md py-tk-sm">
        <span
          className={cn(
            'inline-flex items-center gap-tk-xs text-[12px] font-medium',
            user.isActive ? 'text-success-dark' : 'text-light-text-secondary',
          )}
        >
          <span
            className="h-1.5 w-1.5 rounded-full"
            style={{ backgroundColor: user.isActive ? '#16a34a' : '#a3a3a3' }}
          />
          {user.isActive ? 'Active' : 'Inactive'}
        </span>
      </td>
      <td className="px-tk-md py-tk-sm text-right">
        <div className="relative inline-flex">
          <Link
            to={`/users/edit/${user.id}`}
            className="inline-flex items-center gap-tk-xs rounded-md px-tk-sm py-tk-xs text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <PencilIcon className="h-3.5 w-3.5" />
            Edit
          </Link>
          {!isMe ? (
            <>
              <button
                type="button"
                onClick={() => setMenuOpen((v) => !v)}
                aria-label="More actions"
                className="ml-tk-xs rounded-md p-tk-xs text-light-text-secondary hover:bg-light-subtle"
              >
                <EllipsisHorizontalIcon className="h-4 w-4" />
              </button>
              {menuOpen ? (
                <RowMenu
                  user={user}
                  onClose={() => setMenuOpen(false)}
                  onDeactivate={() => {
                    setMenuOpen(false);
                    onDeactivate();
                  }}
                  onReactivate={() => {
                    setMenuOpen(false);
                    onReactivate();
                  }}
                />
              ) : null}
            </>
          ) : null}
        </div>
      </td>
    </tr>
  );
}

function RowMenu({
  user,
  onClose,
  onDeactivate,
  onReactivate,
}: {
  user: User;
  onClose: () => void;
  onDeactivate: () => void;
  onReactivate: () => void;
}) {
  useEffect(() => {
    const onClick = () => onClose();
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, [onClose]);

  return (
    <div
      onMouseDown={(e) => e.stopPropagation()}
      className="absolute right-0 top-full z-10 mt-tk-xs w-44 overflow-hidden rounded-md border border-light-hairline bg-light-card shadow-lg"
    >
      {user.isActive ? (
        <button
          type="button"
          onClick={onDeactivate}
          className="flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-left text-bodySmall text-error-dark hover:bg-error-light/40"
        >
          <UserMinusIcon className="h-4 w-4" />
          Deactivate
        </button>
      ) : (
        <button
          type="button"
          onClick={onReactivate}
          className="flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-left text-bodySmall text-light-text hover:bg-light-subtle"
        >
          <UserPlusIcon className="h-4 w-4" />
          Reactivate
        </button>
      )}
      <Link
        to={`/users/edit/${user.id}`}
        onMouseDown={(e) => e.stopPropagation()}
        className="flex w-full items-center gap-tk-sm border-t border-light-hairline px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
      >
        <UserIcon className="h-4 w-4" />
        View details
      </Link>
    </div>
  );
}

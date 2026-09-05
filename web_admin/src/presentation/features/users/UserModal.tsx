// The ONE add/manage form (users guide §4), mode from the route: /users/add
// or /users/edit/:id, rendered over the list. No password field in either
// mode — a new account gets an invite email to set its own. Edit mode adds
// Account history and the Danger zone (deactivate first, then delete with a
// typed confirmation). The two permission rules — you cannot change your own
// role; the last active admin cannot be demoted or deactivated — are visible
// here and enforced again by the guards on write.
import { useEffect, useMemo, useState, type KeyboardEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { InformationCircleIcon, ExclamationTriangleIcon } from '@heroicons/react/24/outline';
import { useUsers } from '@/presentation/hooks/useUsers';
import { useNow } from '@/presentation/hooks/useNow';
import { useClearOrphanedLogin, useCreateUser, useDeactivateUser, useDeleteUser, useReactivateUser, useUpdateUser } from '@/presentation/hooks/useUserMutations';
import { useSendPasswordReset } from '@/presentation/hooks/useSendPasswordReset';
import { useAuthStore } from '@/presentation/stores/authStore';
import { RoutePaths } from '@/presentation/router/routePaths';
import { UserRole, userRoleDisplayName } from '@/domain/enums';
import { roleScope, signInStaleness, summarizeUsers } from '@/domain/users/userSignIn';
import { cn } from '@/core/utils/cn';
import { Modal } from '@/presentation/components/ui/Modal';
import { Button } from '@/presentation/components/ui/Button';
import { Field, HistoryEntry, inputCls } from '@/presentation/components/ui/formKit';
import { Skeleton } from '@/presentation/components/ui/Skeleton';
import { toast } from '@/presentation/components/ui/toast';
import { RoleBadge } from './RoleBadge';
import { DeleteUserModal } from './DeleteUserModal';

const ROLES: UserRole[] = [UserRole.admin, UserRole.staff, UserRole.cashier];
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function UserModal() {
  const { id } = useParams<{ id: string }>();
  const mode: 'add' | 'edit' = id ? 'edit' : 'add';
  const navigate = useNavigate();
  const close = () => navigate(RoutePaths.users);
  const me = useAuthStore((s) => s.user);
  const now = useNow();
  const { data, error: usersError } = useUsers(true);
  const loaded = data !== undefined;
  const users = useMemo(() => data ?? [], [data]);
  const target = useMemo(() => (id ? users.find((u) => u.id === id) ?? null : null), [users, id]);
  const summary = useMemo(() => summarizeUsers(users, now), [users, now]);
  const nameOf = (uid: string | null) => (uid ? users.find((u) => u.id === uid)?.displayName ?? 'Unknown' : 'System');

  const create = useCreateUser();
  const update = useUpdateUser();
  const deactivate = useDeactivateUser();
  const reactivate = useReactivateUser();
  const remove = useDeleteUser();
  const resend = useSendPasswordReset();
  const clearOrphan = useClearOrphanedLogin();
  /** Set when Send invite hit a login left behind by an earlier delete. */
  const [orphanEmail, setOrphanEmail] = useState<string | null>(null);

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState<UserRole>(UserRole.cashier);
  const [emailError, setEmailError] = useState<string | null>(null);
  const [nameError, setNameError] = useState<string | null>(null);
  const [confirmDeactivate, setConfirmDeactivate] = useState(false);
  const [hydratedFor, setHydratedFor] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);
  /** Set when the account was minted but the invite email failed. */
  const [inviteFailedFor, setInviteFailedFor] = useState<string | null>(null);

  // Hydrate once per target; later snapshot updates (a deactivation) must
  // not wipe what the admin is typing.
  useEffect(() => {
    if (mode === 'edit' && target && hydratedFor !== target.id) {
      setName(target.displayName);
      setEmail(target.email);
      setRole(target.role);
      setHydratedFor(target.id);
    }
  }, [mode, target, hydratedFor]);

  const isSelf = mode === 'edit' && !!me && !!target && target.id === me.id;
  const lastAdmin =
    mode === 'edit' && !!target && !isSelf && target.role === UserRole.admin && target.isActive && summary.activeAdminCount <= 1;
  const busy = create.isPending || update.isPending || deactivate.isPending || reactivate.isPending || remove.isPending;
  const canSave = name.trim().length > 0 && email.trim().length > 0 && !busy;
  const saveError = (mode === 'add' ? create.error : update.error)?.message ?? null;

  const save = async () => {
    if (!canSave) return;
    let invalid = false;
    if (name.trim().length < 2) {
      setNameError('Name must be at least 2 characters');
      invalid = true;
    } else setNameError(null);
    if (!EMAIL.test(email.trim())) {
      setEmailError('Enter a valid email address');
      invalid = true;
    } else setEmailError(null);
    if (invalid) return;
    try {
      if (mode === 'add') {
        const result = await create.mutateAsync({ email: email.trim(), displayName: name.trim(), role });
        if (result.inviteSent) {
          toast.success('Invite sent', result.user.email);
          close();
        } else {
          setInviteFailedFor(result.user.email);
          toast.error('Account created, but the invite email failed', result.user.email);
        }
      } else if (target) {
        // Only send the role when THIS form changed it: a role someone else
        // changed while the modal was open must not be reverted by a rename.
        await update.mutateAsync({
          target,
          displayName: name.trim(),
          role: role !== target.role ? role : undefined,
        });
        toast.success('User saved', target.email);
        close();
      }
    } catch (e) {
      const msg = (e as Error).message ?? '';
      if (/email-already-in-use/i.test(msg)) {
        setEmailError('This email still has a login from a deleted account.');
        setOrphanEmail(email.trim().toLowerCase());
      } else if (/already/i.test(msg)) {
        setEmailError('This email already has an account');
      } else if (/invalid-email/i.test(msg)) {
        setEmailError('Enter a valid email address');
      }
    }
  };

  const sendReset = () => {
    if (!target) return;
    const invite = target.lastLoginAt === null;
    resend
      .mutateAsync(target.email)
      .then(() => toast.success(invite ? 'Invite sent' : 'Password reset sent', target.email))
      .catch(() => undefined);
  };

  const onRoleKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const dir = e.key === 'ArrowDown' || e.key === 'ArrowRight' ? 1 : e.key === 'ArrowUp' || e.key === 'ArrowLeft' ? -1 : 0;
    if (!dir) return;
    e.preventDefault();
    const enabled = ROLES.filter((r) => !(lastAdmin && r !== UserRole.admin));
    const i = enabled.indexOf(role);
    setRole(enabled[(i + dir + enabled.length) % enabled.length]);
  };

  const initial = (name || email || '?').charAt(0).toUpperCase();
  const missing = mode === 'edit' && loaded && !target;

  return (
    <>
      <Modal
        open
        onClose={() => { if (!busy) close(); }}
        widthClassName="max-w-[540px]"
        title={mode === 'edit' ? 'Manage user' : 'Add user'}
        subtitle={mode === 'edit' ? target?.email ?? '' : 'They set their own password from an invite email'}
        initialFocus={mode === 'edit' ? 'none' : 'first-input'}
        icon={
          <div className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-ctl border border-accent-line bg-accent-soft">
            <span className="font-mono text-[13px] font-semibold text-accent-text">{initial}</span>
          </div>
        }
        footer={
          <div className="flex items-center gap-[9px]">
            <span className="text-[11px] text-ink-3">
              {missing ? '' : mode === 'edit' ? 'Saving records you as the last editor' : 'An invite email goes out on save'}
            </span>
            <div className="ml-auto flex gap-2">
              <Button variant="secondary" onClick={close} disabled={busy}>{missing ? 'Close' : 'Cancel'}</Button>
              {missing ? null : inviteFailedFor ? (
                <Button
                  variant="primary"
                  loading={resend.isPending}
                  onClick={() =>
                    resend.mutateAsync(inviteFailedFor).then(() => { toast.success('Invite sent', inviteFailedFor); close(); }).catch(() => undefined)
                  }
                >
                  Resend invite
                </Button>
              ) : (
                <Button variant="primary" onClick={save} disabled={!canSave || (mode === 'edit' && !target)} loading={create.isPending || update.isPending}>
                  {mode === 'edit' ? 'Save changes' : 'Send invite'}
                </Button>
              )}
            </div>
          </div>
        }
      >
        {mode === 'edit' && !loaded ? (
          <div className="flex flex-col gap-3" aria-busy="true">
            <Skeleton height="42px" />
            <Skeleton height="42px" />
            <Skeleton height="150px" />
          </div>
        ) : missing ? (
          <p className="py-6 text-center text-ctl-md text-ink-2">
            {usersError ? 'Could not load this account.' : 'This account no longer exists.'}
          </p>
        ) : (
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] gap-3">
            <Field label="Name" error={nameError ?? undefined}>
              <input type="text" value={name} onChange={(e) => { setName(e.target.value); setNameError(null); }} placeholder="Full name" autoComplete="name" className={inputCls(!!nameError)} />
            </Field>
            <Field label="Email" error={emailError ?? undefined}>
              <input
                type="email"
                value={email}
                onChange={(e) => { setEmail(e.target.value); setEmailError(null); setOrphanEmail(null); }}
                placeholder="name@example.com"
                autoComplete="email"
                disabled={mode === 'edit'}
                className={cn(inputCls(!!emailError), mode === 'edit' && 'cursor-not-allowed text-ink-2')}
              />
            </Field>
          </div>

          {/* Role */}
          <div className="flex flex-col gap-2">
            <span className="text-[11.5px] font-semibold text-ink-2">Role</span>
            {isSelf && target ? (
              <div className="flex flex-col gap-2 rounded-ctl border border-line bg-surface-2 px-[13px] py-3">
                <div className="flex items-center gap-2">
                  <RoleBadge role={target.role} />
                  <span className="text-[11.5px] text-ink-2">{roleScope[target.role].can}</span>
                </div>
                <span className="text-[11.5px] text-ink-3 [text-wrap:pretty]">
                  This is your own account. Ask another admin to change your role.
                </span>
              </div>
            ) : (
              <div role="radiogroup" aria-label="Role" onKeyDown={onRoleKey} className="flex flex-col gap-1.5">
                {ROLES.map((r) => {
                  const on = role === r;
                  const blocked = lastAdmin && r !== UserRole.admin;
                  return (
                    <button
                      key={r}
                      type="button"
                      role="radio"
                      aria-checked={on}
                      aria-disabled={blocked || undefined}
                      tabIndex={on ? 0 : -1}
                      onClick={() => { if (!blocked) setRole(r); }}
                      className={cn(
                        'flex w-full items-start gap-[11px] rounded-ctl border px-[13px] py-[11px] text-left',
                        on ? 'border-accent-text bg-accent-soft' : 'border-line bg-surface-2',
                        blocked && 'cursor-not-allowed opacity-50',
                      )}
                    >
                      <span className={cn('mt-[1px] flex h-[15px] w-[15px] shrink-0 items-center justify-center rounded-full border', on ? 'border-accent-text bg-accent' : 'border-line bg-surface')}>
                        <span className={cn('block h-1.5 w-1.5 rounded-full', on ? 'bg-accent-ink' : 'bg-transparent')} />
                      </span>
                      <span className="flex min-w-0 flex-col gap-0.5">
                        <span className={cn('text-ctl-md font-semibold', on ? 'text-accent-text' : 'text-ink')}>{userRoleDisplayName[r]}</span>
                        <span className="text-[11.5px] text-ink-3 [text-wrap:pretty]">
                          {blocked ? 'Unavailable while this is the only admin.' : roleScope[r].desc}
                        </span>
                      </span>
                    </button>
                  );
                })}
                {lastAdmin ? (
                  <span className="px-0.5 text-[11.5px] text-neg [text-wrap:pretty]">
                    This is the only active admin. Promote someone else before changing this role.
                  </span>
                ) : null}
              </div>
            )}
          </div>

          {mode === 'add' ? (
            <div className="flex items-center gap-2.5 rounded-ctl border border-info bg-info-soft px-[13px] py-[11px]">
              <InformationCircleIcon className="h-[15px] w-[15px] shrink-0 text-info" />
              <span className="text-[11.5px] text-info [text-wrap:pretty]">
                They will get an email to set their own password. You never see or set it.
              </span>
            </div>
          ) : null}

          {orphanEmail ? (
            <div className="flex flex-wrap items-center gap-3 rounded-ctl border border-line bg-surface-2 px-[13px] py-[11px]">
              <span className="min-w-[150px] flex-1 text-[11.5px] text-ink-2 [text-wrap:pretty]">
                Clear the old login, then the invite goes out to this address.
              </span>
              {clearOrphan.error ? <span className="text-[11.5px] text-neg">{clearOrphan.error.message}</span> : null}
              <Button
                variant="secondary"
                size="sm"
                loading={clearOrphan.isPending}
                onClick={() =>
                  clearOrphan
                    .mutateAsync(orphanEmail)
                    .then(() => { toast.success('Old login cleared', orphanEmail); setOrphanEmail(null); setEmailError(null); return save(); })
                    .catch(() => undefined)
                }
              >
                Clear old login
              </Button>
            </div>
          ) : null}
          {saveError && !emailError && !nameError ? <p className="text-ctl-sm text-neg">{saveError}</p> : null}
          {inviteFailedFor && resend.error ? <p className="text-ctl-sm text-neg">Invite email failed again: {resend.error.message}</p> : null}

          {mode === 'edit' && target ? (
            <>
              {/* Account history — person + timestamp as ONE entry each (shared HistoryEntry) */}
              <div className="flex flex-col gap-2">
                <span className="text-micro-caps uppercase text-ink-3">Account history</span>
                <div className="grid grid-cols-[repeat(auto-fit,minmax(160px,1fr))] gap-2.5">
                  <HistoryEntry inset label="Added by" who={nameOf(target.createdBy)} when={target.createdAt} />
                  <HistoryEntry inset label="Last updated by" who={target.updatedBy ? nameOf(target.updatedBy) : null} when={target.updatedAt} emptyWhenText="Never edited" />
                  <HistoryEntry
                    inset
                    label="Last sign-in"
                    who={target.lastLoginAt ? signInStaleness(target.lastLoginAt, now).label : 'Never'}
                    when={target.lastLoginAt}
                    emptyWhenText="invite not accepted"
                  />
                </div>
                <div className="flex flex-wrap items-center gap-3">
                  <Link to={RoutePaths.userLogs} className="w-fit border-b border-line text-[11.5px] text-ink-2 hover:text-accent-text">
                    View activity logs →
                  </Link>
                  <div className="ml-auto flex items-center gap-2">
                    {resend.error && !inviteFailedFor ? <span className="text-[11.5px] text-neg">{resend.error.message}</span> : null}
                    <Button variant="secondary" size="sm" loading={resend.isPending} onClick={sendReset}>
                      {target.lastLoginAt ? 'Send password reset' : 'Resend invite'}
                    </Button>
                  </div>
                </div>
              </div>

              {/* Danger zone */}
              <div className="flex flex-col gap-[11px] rounded-ctl border border-neg px-3.5 py-[13px]">
                <div className="flex items-center gap-2">
                  <ExclamationTriangleIcon className="h-3.5 w-3.5 text-neg" />
                  <span className="text-[11.5px] font-semibold tracking-[0.2px] text-neg">Danger zone</span>
                </div>
                {isSelf ? (
                  <span className="text-[11.5px] text-ink-3 [text-wrap:pretty]">This is your own account. Ask another admin to deactivate it.</span>
                ) : (
                  <div className="flex flex-col gap-2.5">
                    <div className="flex flex-wrap items-center gap-3">
                      <span className="min-w-[150px] flex-1 text-[11.5px] text-ink-3 [text-wrap:pretty]">
                        {target.isActive
                          ? 'They keep their history but cannot sign in. Reversible.'
                          : 'They can sign in again with the same password.'}
                      </span>
                      <Button
                        variant="secondary"
                        size="sm"
                        loading={reactivate.isPending}
                        onClick={() =>
                          target.isActive
                            ? (deactivate.reset(), setConfirmDeactivate(true))
                            : reactivate.mutateAsync(target).then(() => toast.success('Account reactivated', target.displayName)).catch(() => undefined)
                        }
                      >
                        {target.isActive ? 'Deactivate account' : 'Reactivate account'}
                      </Button>
                    </div>
                    {reactivate.error ? <p className="text-ctl-sm text-neg">{reactivate.error.message}</p> : null}
                    <div className="flex flex-wrap items-center gap-3 border-t border-line-2 pt-2.5">
                      <span className="min-w-[150px] flex-1 text-[11.5px] text-ink-3 [text-wrap:pretty]">
                        {target.isActive
                          ? 'Deactivate first. Their sales and job orders stay in the system either way.'
                          : 'Removes the login. Their sales, job orders and logs stay, still attributed to them.'}
                      </span>
                      <Button variant="danger" size="sm" disabled={target.isActive} onClick={() => { remove.reset(); setDeleting(true); }}>
                        Delete account
                      </Button>
                    </div>
                  </div>
                )}
              </div>
            </>
          ) : null}
        </div>
        )}
      </Modal>

      {/* Deactivation confirms — a mis-click here signs a cashier out mid-shift. */}
      <Modal
        open={confirmDeactivate && !!target}
        onClose={() => { if (!deactivate.isPending) setConfirmDeactivate(false); }}
        size="sm"
        title="Deactivate account?"
        initialFocus="none"
        footer={
          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setConfirmDeactivate(false)} disabled={deactivate.isPending}>Cancel</Button>
            <Button
              variant="danger"
              loading={deactivate.isPending}
              onClick={() =>
                target
                  ? deactivate.mutateAsync(target).then(() => { toast.info('Account deactivated', target.displayName); setConfirmDeactivate(false); }).catch(() => undefined)
                  : undefined
              }
            >
              Deactivate
            </Button>
          </div>
        }
      >
        {target ? (
          <div className="flex flex-col gap-3">
            <p className="text-ctl-sm text-ink-2 [text-wrap:pretty]">
              {target.displayName || target.email} will no longer be able to sign in, and any open session ends now.
              Their history stays, and you can reactivate them later.
            </p>
            {deactivate.error ? <p className="text-ctl-sm text-neg">{deactivate.error.message}</p> : null}
          </div>
        ) : null}
      </Modal>

      <DeleteUserModal
        target={deleting && target ? target : null}
        busy={remove.isPending}
        error={remove.error?.message ?? null}
        onClose={() => setDeleting(false)}
        onConfirm={() =>
          target
            ? remove.mutateAsync(target).then(() => { toast.info('Account deleted', target.displayName); setDeleting(false); close(); }).catch(() => undefined)
            : undefined
        }
      />
    </>
  );
}

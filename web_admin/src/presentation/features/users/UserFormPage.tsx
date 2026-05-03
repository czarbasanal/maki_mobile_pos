// /admin/users/add and /admin/users/edit/:id — single page covering both
// modes. Mirrors the Flutter user_form_screen with a tighter layout:
// avatar/role banner, email + display-name inputs, role picker, password
// fields (create mode only).

import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  ArrowLeftIcon,
  CheckCircleIcon,
  EyeIcon,
  EyeSlashIcon,
} from '@heroicons/react/24/outline';
import { useUser } from '@/presentation/hooks/useUsers';
import {
  useCreateUser,
  useUpdateUser,
} from '@/presentation/hooks/useUserMutations';
import { useSendPasswordReset } from '@/presentation/hooks/useSendPasswordReset';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { useAuthStore } from '@/presentation/stores/authStore';
import { RoutePaths } from '@/presentation/router/routePaths';
import { UserRole, userRoleDisplayName } from '@/domain/enums';
import { toneBadgeClasses, type Tone } from '@/core/theme/tones';
import { cn } from '@/core/utils/cn';

const roleTones: Record<UserRole, Tone> = {
  admin: 'violet',
  staff: 'green',
  cashier: 'blue',
};

const roleDescription: Record<UserRole, string> = {
  admin: 'Full access including user management and cost visibility',
  staff: 'POS, inventory, receiving (no cost visibility)',
  cashier: 'POS operations only',
};

const baseSchema = {
  email: z.string().trim().min(1, 'Email is required').email('Invalid email'),
  displayName: z.string().trim().min(2, 'Display name must be at least 2 characters'),
  role: z.enum([UserRole.admin, UserRole.staff, UserRole.cashier]),
};

const createSchema = z
  .object({
    ...baseSchema,
    password: z.string().min(6, 'Password must be at least 6 characters'),
    confirmPassword: z.string().min(1, 'Please confirm the password'),
  })
  .refine((v) => v.password === v.confirmPassword, {
    path: ['confirmPassword'],
    message: 'Passwords do not match',
  });

const editSchema = z.object({
  ...baseSchema,
  password: z.string().optional(),
  confirmPassword: z.string().optional(),
});

type FormValues = z.infer<typeof createSchema>;

export function UserFormPage() {
  const params = useParams<{ id?: string }>();
  const editingId = params.id;
  const isEditing = !!editingId;
  const navigate = useNavigate();
  const me = useAuthStore((s) => s.user);

  const { data: target, isLoading, error } = useUser(editingId);
  const create = useCreateUser();
  const update = useUpdateUser();
  const sendReset = useSendPasswordReset();

  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [resetSent, setResetSent] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    setError,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(isEditing ? (editSchema as never) : createSchema),
    defaultValues: {
      email: '',
      displayName: '',
      role: UserRole.cashier,
      password: '',
      confirmPassword: '',
    },
  });

  useEffect(() => {
    document.title = isEditing
      ? 'Edit user · MAKI POS Admin'
      : 'New user · MAKI POS Admin';
  }, [isEditing]);

  // Hydrate the form when the target user loads.
  useEffect(() => {
    if (!target) return;
    reset({
      email: target.email,
      displayName: target.displayName,
      role: target.role,
      password: '',
      confirmPassword: '',
    });
  }, [target, reset]);

  const selectedRole = watch('role');
  const isMe = useMemo(
    () => Boolean(isEditing && me && target && me.id === target.id),
    [isEditing, me, target],
  );

  if (isEditing && error) {
    return <ErrorView title="Could not load user" message={error.message} />;
  }
  if (isEditing && !target) {
    return <LoadingView label="Loading user…" />;
  }
  if (isEditing && isLoading) {
    return <LoadingView label="Loading user…" />;
  }

  const submitting = isSubmitting || create.isPending || update.isPending;
  const mutationError = create.error?.message ?? update.error?.message ?? null;

  const onSubmit = async (values: FormValues) => {
    if (isEditing) {
      if (!target) return;
      try {
        await update.mutateAsync({
          target,
          displayName: values.displayName,
          role: values.role,
        });
        navigate(RoutePaths.users);
      } catch {
        // surfaces via mutationError
      }
      return;
    }
    try {
      await create.mutateAsync({
        email: values.email,
        displayName: values.displayName,
        role: values.role,
        password: values.password ?? '',
      });
      navigate(RoutePaths.users);
    } catch (e) {
      const fb = e as { code?: string; message?: string };
      if (fb.code === 'auth/email-already-in-use') {
        setError('email', { type: 'auth', message: 'This email is already in use' });
      } else if (fb.code === 'auth/weak-password') {
        setError('password', { type: 'auth', message: 'Password is too weak' });
      }
    }
  };

  const onSendReset = async () => {
    if (!target) return;
    sendReset.reset();
    setResetSent(null);
    try {
      await sendReset.mutateAsync(target.email);
      setResetSent(target.email);
    } catch {
      // sendReset.error surfaces below
    }
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="space-y-tk-sm">
        <Link
          to={RoutePaths.users}
          className="inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
        >
          <ArrowLeftIcon className="h-3.5 w-3.5" />
          Users
        </Link>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          {isEditing ? 'Edit user' : 'New user'}
        </h1>
      </header>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-tk-lg" noValidate>
        <div className="flex items-center gap-tk-md rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-primary-dark text-bodyMedium font-semibold text-white">
            {(target?.displayName || target?.email || '?')[0]?.toUpperCase() ?? '?'}
          </span>
          <div className="min-w-0 flex-1">
            <div className="text-bodyMedium font-semibold text-light-text">
              {target?.displayName || (isEditing ? '—' : 'New account')}
            </div>
            <div className="text-bodySmall text-light-text-secondary">
              {target?.email || 'Choose a role and email below'}
            </div>
          </div>
          <span
            className={`inline-flex items-center rounded-full px-tk-sm py-[1px] text-[11px] font-semibold uppercase tracking-wider ${toneBadgeClasses[roleTones[selectedRole]]}`}
          >
            {userRoleDisplayName[selectedRole]}
          </span>
        </div>

        {mutationError ? (
          <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
            {mutationError}
          </p>
        ) : null}

        {resetSent ? (
          <div className="flex items-start gap-tk-sm rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
            <CheckCircleIcon className="mt-[2px] h-4 w-4 shrink-0 text-success" />
            <span>Password reset email sent to {resetSent}.</span>
          </div>
        ) : null}

        <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
          <Field
            label="Email"
            error={errors.email?.message}
            input={
              <input
                type="email"
                autoComplete="email"
                disabled={isEditing}
                className={inputCls(!!errors.email, isEditing)}
                {...register('email')}
              />
            }
            hint={isEditing ? "Email can't be changed after creation." : undefined}
          />
          <Field
            label="Display name"
            error={errors.displayName?.message}
            input={
              <input
                type="text"
                autoComplete="name"
                className={inputCls(!!errors.displayName)}
                {...register('displayName')}
              />
            }
          />
        </div>

        <fieldset className="space-y-tk-sm">
          <legend className="text-bodySmall font-medium text-light-text">Role</legend>
          {([UserRole.admin, UserRole.staff, UserRole.cashier] as UserRole[]).map((role) => {
            const selected = selectedRole === role;
            const blocked = isMe && role !== target?.role;
            return (
              <button
                type="button"
                key={role}
                onClick={() => !blocked && setValue('role', role)}
                disabled={blocked}
                className={cn(
                  'flex w-full items-center gap-tk-md rounded-lg border p-tk-md text-left transition-colors disabled:cursor-not-allowed disabled:opacity-60',
                  selected
                    ? 'border-light-text bg-light-subtle'
                    : 'border-light-hairline bg-light-card hover:bg-light-subtle',
                )}
              >
                <span
                  className={`grid h-9 w-9 shrink-0 place-items-center rounded-md ${toneBadgeClasses[roleTones[role]]} text-[12px] font-bold`}
                >
                  {role[0].toUpperCase()}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="text-bodyMedium font-semibold text-light-text">
                    {userRoleDisplayName[role]}
                  </div>
                  <div className="text-bodySmall text-light-text-secondary">
                    {roleDescription[role]}
                  </div>
                </div>
                {selected ? <CheckCircleIcon className="h-5 w-5 text-light-text" /> : null}
              </button>
            );
          })}
          {isMe ? (
            <p className="text-[12px] text-light-text-hint">
              You can't change your own role. Ask another admin if you need this.
            </p>
          ) : null}
        </fieldset>

        {!isEditing ? (
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            <Field
              label="Password"
              error={errors.password?.message}
              input={
                <div className="relative">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    autoComplete="new-password"
                    className={cn(inputCls(!!errors.password), 'pr-10')}
                    {...register('password')}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((v) => !v)}
                    className="absolute right-2 top-1/2 -translate-y-1/2 rounded-md p-tk-xs text-light-text-secondary hover:bg-light-subtle"
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? (
                      <EyeSlashIcon className="h-4 w-4" />
                    ) : (
                      <EyeIcon className="h-4 w-4" />
                    )}
                  </button>
                </div>
              }
            />
            <Field
              label="Confirm password"
              error={errors.confirmPassword?.message}
              input={
                <div className="relative">
                  <input
                    type={showConfirm ? 'text' : 'password'}
                    autoComplete="new-password"
                    className={cn(inputCls(!!errors.confirmPassword), 'pr-10')}
                    {...register('confirmPassword')}
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirm((v) => !v)}
                    className="absolute right-2 top-1/2 -translate-y-1/2 rounded-md p-tk-xs text-light-text-secondary hover:bg-light-subtle"
                    aria-label={showConfirm ? 'Hide password' : 'Show password'}
                  >
                    {showConfirm ? (
                      <EyeSlashIcon className="h-4 w-4" />
                    ) : (
                      <EyeIcon className="h-4 w-4" />
                    )}
                  </button>
                </div>
              }
            />
          </div>
        ) : (
          <div className="rounded-lg border border-light-hairline bg-light-card p-tk-md">
            <div className="flex items-center justify-between">
              <div className="min-w-0">
                <div className="text-bodyMedium font-semibold text-light-text">
                  Reset password
                </div>
                <div className="text-bodySmall text-light-text-secondary">
                  Sends a Firebase reset email so the user can choose a new one.
                </div>
              </div>
              <button
                type="button"
                onClick={onSendReset}
                disabled={sendReset.isPending}
                className="flex shrink-0 items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle disabled:opacity-60"
              >
                {sendReset.isPending ? <Spinner className="h-3.5 w-3.5" /> : null}
                {sendReset.isPending ? 'Sending…' : 'Send reset email'}
              </button>
            </div>
            {sendReset.error ? (
              <p className="mt-tk-sm text-bodySmall text-error">{sendReset.error.message}</p>
            ) : null}
          </div>
        )}

        <div className="flex justify-end gap-tk-sm">
          <Link
            to={RoutePaths.users}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
          >
            Cancel
          </Link>
          <button
            type="submit"
            disabled={submitting}
            className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
          >
            {submitting ? <Spinner className="h-3.5 w-3.5" /> : null}
            {submitting ? 'Saving…' : isEditing ? 'Save changes' : 'Create user'}
          </button>
        </div>
      </form>
    </div>
  );
}

function inputCls(hasError: boolean, disabled = false): string {
  return cn(
    'w-full rounded-md border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none transition-colors',
    'focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0',
    hasError ? 'border-error focus:border-error focus:outline-error' : 'border-light-border',
    disabled && 'cursor-not-allowed bg-light-subtle text-light-text-secondary',
  );
}

function Field({
  label,
  error,
  hint,
  input,
}: {
  label: string;
  error?: string;
  hint?: string;
  input: React.ReactNode;
}) {
  return (
    <label className="block space-y-tk-xs">
      <span className="text-bodySmall font-medium text-light-text">{label}</span>
      {input}
      {error ? (
        <span className="block text-[12px] text-error">{error}</span>
      ) : hint ? (
        <span className="block text-[12px] text-light-text-hint">{hint}</span>
      ) : null}
    </label>
  );
}


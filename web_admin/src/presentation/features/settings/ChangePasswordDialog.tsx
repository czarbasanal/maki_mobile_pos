import { useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Dialog } from '@/presentation/components/common/Dialog';
import { Spinner } from '@/presentation/components/common/LoadingView';
import { useChangePassword } from '@/presentation/hooks/useChangePassword';
import { cn } from '@/core/utils/cn';

const schema = z
  .object({
    currentPassword: z.string().min(1, 'Current password is required'),
    newPassword: z.string().min(6, 'New password must be at least 6 characters'),
    confirmPassword: z.string().min(1, 'Please confirm the new password'),
  })
  .refine((v) => v.newPassword === v.confirmPassword, {
    path: ['confirmPassword'],
    message: 'Passwords do not match',
  });

type ChangePasswordValues = z.infer<typeof schema>;

export function ChangePasswordDialog({
  open,
  onClose,
  onSuccess,
}: {
  open: boolean;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const change = useChangePassword();
  const [genericError, setGenericError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    reset,
    setError,
    formState: { errors },
  } = useForm<ChangePasswordValues>({
    resolver: zodResolver(schema),
    defaultValues: { currentPassword: '', newPassword: '', confirmPassword: '' },
  });

  useEffect(() => {
    if (!open) {
      reset();
      change.reset();
      setGenericError(null);
    }
  }, [open, reset, change]);

  const onSubmit = async (values: ChangePasswordValues) => {
    setGenericError(null);
    try {
      await change.mutateAsync({
        currentPassword: values.currentPassword,
        newPassword: values.newPassword,
      });
      onSuccess();
    } catch (e) {
      const fb = e as { code?: string; message?: string };
      if (fb.code === 'auth/wrong-password' || fb.code === 'auth/invalid-credential') {
        setError('currentPassword', {
          type: 'auth',
          message: 'Current password is incorrect',
        });
      } else {
        setGenericError(fb.message ?? 'Could not change password');
      }
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Change password"
      description="Enter your current password, then choose a new one."
      dismissable={!change.isPending}
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-tk-md" noValidate>
        <Field
          label="Current password"
          error={errors.currentPassword?.message}
          input={
            <input
              type="password"
              autoComplete="current-password"
              autoFocus
              className={inputCls(!!errors.currentPassword)}
              {...register('currentPassword')}
            />
          }
        />
        <Field
          label="New password"
          error={errors.newPassword?.message}
          input={
            <input
              type="password"
              autoComplete="new-password"
              className={inputCls(!!errors.newPassword)}
              {...register('newPassword')}
            />
          }
        />
        <Field
          label="Confirm new password"
          error={errors.confirmPassword?.message}
          input={
            <input
              type="password"
              autoComplete="new-password"
              className={inputCls(!!errors.confirmPassword)}
              {...register('confirmPassword')}
            />
          }
        />
        {genericError ? (
          <p className="text-bodySmall text-error">{genericError}</p>
        ) : null}
        <div className="flex justify-end gap-tk-sm pt-tk-sm">
          <button
            type="button"
            onClick={onClose}
            disabled={change.isPending}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={change.isPending}
            className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
          >
            {change.isPending ? <Spinner className="h-3.5 w-3.5" /> : null}
            {change.isPending ? 'Updating…' : 'Change password'}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

function inputCls(hasError: boolean): string {
  return cn(
    'w-full rounded-md border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none transition-colors',
    'focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0',
    hasError ? 'border-error focus:border-error focus:outline-error' : 'border-light-border',
  );
}

function Field({
  label,
  error,
  input,
}: {
  label: string;
  error?: string;
  input: React.ReactNode;
}) {
  return (
    <label className="block space-y-tk-xs">
      <span className="text-bodySmall font-medium text-light-text">{label}</span>
      {input}
      {error ? <span className="block text-[12px] text-error">{error}</span> : null}
    </label>
  );
}

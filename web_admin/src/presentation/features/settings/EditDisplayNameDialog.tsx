// Modal for editing the signed-in admin's display name. Self-edit only —
// admin editing other users uses /admin/users/edit/:id.

import { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Dialog } from '@/presentation/components/common/Dialog';
import { Spinner } from '@/presentation/components/common/LoadingView';
import { useUpdateUser } from '@/presentation/hooks/useUserMutations';
import type { User } from '@/domain/entities';
import { cn } from '@/core/utils/cn';

const schema = z.object({
  displayName: z.string().trim().min(2, 'Display name must be at least 2 characters'),
});

type Values = z.infer<typeof schema>;

export function EditDisplayNameDialog({
  open,
  user,
  onClose,
  onSuccess,
}: {
  open: boolean;
  user: User;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const update = useUpdateUser();
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: { displayName: user.displayName },
  });

  useEffect(() => {
    if (open) {
      reset({ displayName: user.displayName });
      update.reset();
    }
  }, [open, user.displayName, reset, update]);

  const onSubmit = async (values: Values) => {
    if (values.displayName === user.displayName) {
      onClose();
      return;
    }
    try {
      await update.mutateAsync({ target: user, displayName: values.displayName });
      onSuccess();
    } catch {
      // surfaced via update.error below
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Edit display name"
      description="The name shown next to your sign-ins and audit log entries."
      dismissable={!update.isPending}
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-tk-md" noValidate>
        <label className="block space-y-tk-xs">
          <span className="text-bodySmall font-medium text-light-text">Display name</span>
          <input
            type="text"
            autoFocus
            autoComplete="name"
            className={cn(
              'w-full rounded-md border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none transition-colors',
              'focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0',
              errors.displayName ? 'border-error focus:border-error focus:outline-error' : 'border-light-border',
            )}
            {...register('displayName')}
          />
          {errors.displayName ? (
            <span className="block text-[12px] text-error">{errors.displayName.message}</span>
          ) : null}
        </label>
        {update.error ? (
          <p className="text-bodySmall text-error">{update.error.message}</p>
        ) : null}
        <div className="flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={onClose}
            disabled={update.isPending}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={update.isPending}
            className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
          >
            {update.isPending ? <Spinner className="h-3.5 w-3.5" /> : null}
            {update.isPending ? 'Saving…' : 'Save'}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

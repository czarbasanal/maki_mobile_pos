// /forgot-password — request a Firebase password-reset email. Sibling of
// LoginPage inside AuthLayout; the login form's typed email arrives as
// router state for prefill.

import { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { CheckCircleIcon } from '@heroicons/react/24/outline';
import { useSendPasswordReset } from '@/presentation/hooks/useSendPasswordReset';
import { RoutePaths } from '@/presentation/router/routePaths';
import { Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorBanner, Field, inputCls } from './authUi';

const resetSchema = z.object({
  email: z.string().trim().min(1, 'Email is required').email('Invalid email address'),
});

type ResetValues = z.infer<typeof resetSchema>;

export function ForgotPasswordPage() {
  const location = useLocation();
  const prefill = (location.state as { email?: string } | null)?.email ?? '';
  const [sentTo, setSentTo] = useState<string | null>(null);
  const sendReset = useSendPasswordReset();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<ResetValues>({
    resolver: zodResolver(resetSchema),
    defaultValues: { email: prefill },
  });

  useEffect(() => {
    document.title = 'Reset password · MAKI POS Admin';
  }, []);

  const onSubmit = async (values: ResetValues) => {
    sendReset.reset();
    const email = values.email.trim();
    try {
      await sendReset.mutateAsync(email);
      setSentTo(email);
    } catch {
      // Error surfaces via sendReset.error below.
    }
  };

  if (sentTo) {
    return (
      <div className="space-y-tk-xl">
        <div className="flex flex-col items-center text-center">
          <CheckCircleIcon className="h-10 w-10 text-success" />
          <h1 className="mt-tk-md text-bodyLarge font-semibold tracking-tight text-light-text">
            Check your inbox
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Reset email sent to <span className="font-semibold">{sentTo}</span> — check
            your inbox.
          </p>
        </div>
        <div className="flex justify-center">
          <Link
            to={RoutePaths.login}
            className="text-bodySmall text-light-text-secondary underline-offset-2 hover:text-light-text hover:underline"
          >
            Back to login
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-tk-xl">
      <div className="flex flex-col items-center text-center">
        <h1 className="text-bodyLarge font-semibold tracking-tight text-light-text">
          Reset password
        </h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Enter your email and we&apos;ll send you a reset link.
        </p>
      </div>

      {sendReset.error ? (
        <ErrorBanner
          message={sendReset.error.message}
          onDismiss={() => sendReset.reset()}
        />
      ) : null}

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-tk-md" noValidate>
        <Field
          label="Email"
          error={errors.email?.message}
          input={
            <input
              type="email"
              autoComplete="email"
              autoFocus
              {...register('email')}
              className={inputCls(!!errors.email)}
            />
          }
        />

        <button
          type="submit"
          disabled={sendReset.isPending}
          className="flex w-full items-center justify-center gap-tk-sm rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background transition-colors hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
        >
          {sendReset.isPending ? <Spinner className="h-4 w-4" /> : null}
          {sendReset.isPending ? 'Sending…' : 'Send reset link'}
        </button>

        <div className="flex justify-center pt-tk-xs">
          <Link
            to={RoutePaths.login}
            className="text-bodySmall text-light-text-secondary underline-offset-2 hover:text-light-text hover:underline"
          >
            Back to login
          </Link>
        </div>
      </form>
    </div>
  );
}

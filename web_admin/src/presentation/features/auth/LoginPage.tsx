// /admin/login form. Mirrors lib/presentation/shared/screens/auth/login_screen.dart:
// branded header, email + password form, inline error banner, forgot-password
// flow, friendly error copy from FirebaseAuthRepository.

import { useEffect, useState } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { AlertCircle, CheckCircle2, Eye, EyeOff, Loader2, X } from 'lucide-react';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useSignIn } from '@/presentation/hooks/useSignIn';
import { useSendPasswordReset } from '@/presentation/hooks/useSendPasswordReset';
import { RoutePaths } from '@/presentation/router/routePaths';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { cn } from '@/core/utils/cn';

const loginSchema = z.object({
  email: z.string().trim().min(1, 'Email is required').email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
});

type LoginValues = z.infer<typeof loginSchema>;

export function LoginPage() {
  const { status, user } = useAuthStore();
  const location = useLocation();
  const navigate = useNavigate();
  const from = (location.state as { from?: string } | null)?.from ?? RoutePaths.dashboard;

  const [showPassword, setShowPassword] = useState(false);
  const [resetMode, setResetMode] = useState(false);
  const [resetSuccess, setResetSuccess] = useState<string | null>(null);

  const signIn = useSignIn();
  const sendReset = useSendPasswordReset();

  const {
    register,
    handleSubmit,
    getValues,
    setError: setFieldError,
    formState: { errors, isSubmitting },
  } = useForm<LoginValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: '', password: '' },
  });

  useEffect(() => {
    document.title = 'Sign in · MAKI POS Admin';
  }, []);

  if (status === 'loading') return <LoadingView label="Restoring session…" />;
  if (status === 'signedIn' && user?.role === 'admin') {
    return <Navigate to={from} replace />;
  }

  const onSubmit = async (values: LoginValues) => {
    signIn.reset();
    setResetSuccess(null);
    try {
      const signedIn = await signIn.mutateAsync(values);
      // The auth store updates via onAuthStateChanged; navigate eagerly so the
      // user sees the dashboard immediately rather than the login screen
      // flashing during the round-trip.
      if (signedIn.role !== 'admin') {
        navigate(RoutePaths.accessDenied, { replace: true });
        return;
      }
      navigate(from, { replace: true });
    } catch (e) {
      // Surface Firebase errors on the password field so the user sees them
      // attached to where they typed, plus the banner above for redundancy.
      const message = e instanceof Error ? e.message : 'Sign-in failed';
      setFieldError('password', { type: 'auth', message });
    }
  };

  const onSendReset = async () => {
    const email = getValues('email').trim();
    if (!email) {
      setFieldError('email', { type: 'manual', message: 'Enter your email first' });
      return;
    }
    if (!z.string().email().safeParse(email).success) {
      setFieldError('email', { type: 'manual', message: 'Invalid email address' });
      return;
    }
    sendReset.reset();
    try {
      await sendReset.mutateAsync(email);
      setResetSuccess(`Password reset email sent to ${email}. Check your inbox.`);
      setResetMode(false);
    } catch {
      // Error surfaces via sendReset.error below.
    }
  };

  const submitting = isSubmitting || signIn.isPending;
  const banner = signIn.error?.message ?? sendReset.error?.message ?? null;

  return (
    <div className="space-y-tk-lg">
      <Header />

      {banner ? <ErrorBanner message={banner} onDismiss={() => signIn.reset()} /> : null}
      {resetSuccess ? <SuccessBanner message={resetSuccess} onDismiss={() => setResetSuccess(null)} /> : null}

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

        <Field
          label="Password"
          error={errors.password?.message}
          input={
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                autoComplete="current-password"
                {...register('password')}
                className={cn(inputCls(!!errors.password), 'pr-10')}
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                className="absolute right-2 top-1/2 -translate-y-1/2 rounded-md p-tk-xs text-light-text-secondary hover:bg-light-surface"
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          }
        />

        <button
          type="submit"
          disabled={submitting}
          className="flex w-full items-center justify-center gap-tk-sm rounded-md bg-brand-slate px-tk-md py-tk-sm text-bodyMedium font-semibold text-white transition-colors hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
        >
          {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
          {submitting ? 'Signing in…' : 'Sign in'}
        </button>

        <div className="flex justify-center">
          {resetMode ? (
            <ResetConfirm
              email={getValues('email').trim()}
              pending={sendReset.isPending}
              onSend={onSendReset}
              onCancel={() => {
                setResetMode(false);
                sendReset.reset();
              }}
            />
          ) : (
            <button
              type="button"
              onClick={() => setResetMode(true)}
              className="text-bodySmall text-light-text-secondary hover:text-light-text"
            >
              Forgot password?
            </button>
          )}
        </div>
      </form>

      <Footer />
    </div>
  );
}

function inputCls(hasError: boolean): string {
  return cn(
    'w-full rounded-md border bg-light-card px-tk-md py-tk-sm text-bodyMedium text-light-text outline-none transition-colors',
    'focus:border-brand-slate focus:ring-2 focus:ring-brand-slate/20',
    hasError ? 'border-error' : 'border-light-border',
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
      <span className="text-labelMedium text-light-text">{label}</span>
      {input}
      {error ? <span className="block text-bodySmall text-error">{error}</span> : null}
    </label>
  );
}

function Header() {
  return (
    <div className="flex flex-col items-center text-center">
      <div className="grid h-16 w-16 place-items-center rounded-[14px] border-[1.2px] border-light-border">
        <span className="text-[26px] font-semibold leading-none text-primary-dark">M</span>
      </div>
      <h1 className="mt-tk-md text-[18px] font-bold tracking-[2.4px] text-primary-dark">
        MAKI POS
      </h1>
      <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
        Sign in to your account
      </p>
    </div>
  );
}

function Footer() {
  return (
    <p className="text-center text-[11px] tracking-[0.5px] text-light-text-hint">v1.0.0</p>
  );
}

function ErrorBanner({ message, onDismiss }: { message: string; onDismiss: () => void }) {
  return (
    <div className="flex items-start gap-tk-sm rounded-md bg-error-light px-tk-md py-tk-sm text-error-dark">
      <AlertCircle className="mt-[2px] h-4 w-4 shrink-0 text-error" />
      <p className="flex-1 text-[13px]">{message}</p>
      <button type="button" onClick={onDismiss} aria-label="Dismiss">
        <X className="h-4 w-4 text-error" />
      </button>
    </div>
  );
}

function SuccessBanner({ message, onDismiss }: { message: string; onDismiss: () => void }) {
  return (
    <div className="flex items-start gap-tk-sm rounded-md bg-success-light px-tk-md py-tk-sm text-success-dark">
      <CheckCircle2 className="mt-[2px] h-4 w-4 shrink-0 text-success" />
      <p className="flex-1 text-[13px]">{message}</p>
      <button type="button" onClick={onDismiss} aria-label="Dismiss">
        <X className="h-4 w-4 text-success" />
      </button>
    </div>
  );
}

function ResetConfirm({
  email,
  pending,
  onSend,
  onCancel,
}: {
  email: string;
  pending: boolean;
  onSend: () => void;
  onCancel: () => void;
}) {
  return (
    <div className="flex w-full flex-col items-center gap-tk-sm rounded-md border border-light-divider bg-light-surface p-tk-md text-center">
      <p className="text-bodySmall text-light-text">
        {email
          ? <>Send password reset email to <span className="font-semibold">{email}</span>?</>
          : 'Enter your email above first.'}
      </p>
      <div className="flex gap-tk-sm">
        <button
          type="button"
          onClick={onCancel}
          className="rounded-md px-tk-md py-tk-xs text-bodySmall text-light-text hover:bg-light-divider/50"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={onSend}
          disabled={pending || !email}
          className="flex items-center gap-tk-xs rounded-md bg-brand-slate px-tk-md py-tk-xs text-bodySmall font-semibold text-white hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
        >
          {pending ? <Loader2 className="h-3 w-3 animate-spin" /> : null}
          {pending ? 'Sending…' : 'Send'}
        </button>
      </div>
    </div>
  );
}

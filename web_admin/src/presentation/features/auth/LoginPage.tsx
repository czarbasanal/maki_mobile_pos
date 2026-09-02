// /login — per design/maki-pos-signin-redesign: the form sits in a 392px
// card on the app's --bg (amber 44px brand mark, accent primary button),
// with an in-card error banner (one generic message, never which field
// failed), password reveal, and a tokenized "Keep me signed in" checkbox
// wired to Firebase persistence. AuthLayout carries the theme toggle and
// the pinned v1.0.0.
import { useEffect, useState } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { CheckIcon, EyeIcon, EyeSlashIcon } from '@heroicons/react/24/outline';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useSignIn } from '@/presentation/hooks/useSignIn';
import { RoutePaths } from '@/presentation/router/routePaths';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { cn } from '@/core/utils/cn';

export function LoginPage() {
  const { status, user } = useAuthStore();
  const location = useLocation();
  const navigate = useNavigate();
  const from = (location.state as { from?: string } | null)?.from ?? RoutePaths.dashboard;

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  // Default OFF (user call): the shop's registers are shared terminals, so a
  // sign-in dies with the browser unless someone deliberately opts in.
  const [remember, setRemember] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const signIn = useSignIn();
  const submitting = signIn.isPending;

  useEffect(() => {
    document.title = 'Sign in · MAKI POS Admin';
  }, []);

  if (status === 'loading') return <LoadingView label="Restoring session…" />;
  if (status === 'signedIn' && (user?.role === 'admin' || user?.role === 'cashier')) {
    return <Navigate to={from} replace />;
  }

  const submit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (submitting) return;
    // Presence only — never say which of the two was wrong.
    if (!email.trim() || !password) {
      setError('Enter your email and password to continue.');
      return;
    }
    setError(null);
    signIn.reset();
    try {
      const signedIn = await signIn.mutateAsync({ email, password, remember });
      if (signedIn.role !== 'admin' && signedIn.role !== 'cashier') {
        navigate(RoutePaths.accessDenied, { replace: true });
        return;
      }
      navigate(from, { replace: true });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign-in failed');
    }
  };

  const hasError = error !== null;
  const fieldCls = cn(
    'w-full rounded-[11px] border bg-surface-2 px-[13px] py-[11px] text-[13.5px] text-ink outline-none transition-colors placeholder:text-ink-3',
    // On error BOTH borders go --neg — the user sees which form failed, not
    // which field. Focus takes the accent line otherwise.
    hasError ? 'border-neg' : 'border-line focus-within:border-accent-line focus:border-accent-line',
  );

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-col items-center gap-[13px]">
        <div className="flex h-11 w-11 items-center justify-center rounded-[13px] bg-accent shadow-[0_4px_12px_-4px_var(--accent-line)]">
          <span className="font-mono text-[19px] font-semibold tracking-[-0.6px] text-accent-ink">
            M
          </span>
        </div>
        <div className="flex flex-col items-center gap-[5px]">
          <h1 className="text-[21px] font-semibold tracking-[-0.55px] text-ink">MAKI POS Admin</h1>
          <span className="text-[13px] text-ink-2">Sign in to continue</span>
        </div>
      </div>

      <form
        onSubmit={submit}
        noValidate
        className="flex flex-col gap-[15px] rounded-[16px] border border-line bg-surface p-[22px] shadow-card-lg"
      >
        {hasError ? (
          <div
            role="alert"
            className="shake flex items-center gap-2.5 rounded-[11px] border border-neg bg-neg-soft px-[13px] py-[11px]"
          >
            <svg
              width="15"
              height="15"
              viewBox="0 0 20 20"
              fill="none"
              stroke="var(--neg)"
              strokeWidth="1.8"
              className="shrink-0"
              aria-hidden
            >
              <circle cx="10" cy="10" r="7" />
              <line x1="10" y1="6.4" x2="10" y2="10.8" />
              <circle cx="10" cy="13.6" r="0.6" fill="var(--neg)" />
            </svg>
            <span className="text-ctl-sm font-medium text-neg">{error}</span>
          </div>
        ) : null}

        <div className="flex flex-col gap-[7px]">
          <label htmlFor="email" className="text-[11.5px] font-semibold tracking-[0.1px] text-ink-2">
            Email
          </label>
          <input
            id="email"
            type="email"
            autoComplete="username"
            autoFocus
            value={email}
            onChange={(e) => {
              setEmail(e.target.value);
              setError(null);
            }}
            placeholder="you@makimotorparts.ph"
            className={fieldCls}
          />
        </div>

        <div className="flex flex-col gap-[7px]">
          <label
            htmlFor="password"
            className="text-[11.5px] font-semibold tracking-[0.1px] text-ink-2"
          >
            Password
          </label>
          <div
            className={cn(
              'flex items-center gap-[9px] rounded-[11px] border bg-surface-2 px-[13px] py-[11px] transition-colors focus-within:border-accent-line',
              hasError ? 'border-neg focus-within:border-neg' : 'border-line',
            )}
          >
            <input
              id="password"
              type={show ? 'text' : 'password'}
              autoComplete="current-password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                setError(null);
              }}
              placeholder="••••••••"
              className="w-full bg-transparent text-[13.5px] text-ink outline-none placeholder:text-ink-3"
            />
            <button
              type="button"
              onClick={() => setShow((v) => !v)}
              title={show ? 'Hide password' : 'Show password'}
              className="flex h-6 w-6 shrink-0 items-center justify-center rounded-[7px] text-ink-3 hover:bg-surface-3 hover:text-ink-2"
            >
              {show ? <EyeSlashIcon className="h-[15px] w-[15px]" /> : <EyeIcon className="h-[15px] w-[15px]" />}
            </button>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            type="button"
            role="checkbox"
            aria-checked={remember}
            onClick={() => setRemember((v) => !v)}
            className="flex items-center gap-[9px]"
          >
            <span
              aria-hidden
              className={cn(
                'flex h-[17px] w-[17px] shrink-0 items-center justify-center rounded-[5px] border',
                remember ? 'border-accent-line bg-accent' : 'border-line bg-surface-2',
              )}
            >
              {remember ? <CheckIcon className="h-3 w-3 stroke-[3] text-accent-ink" /> : null}
            </span>
            <span className="text-ctl-sm text-ink-2">Keep me signed in</span>
          </button>
          <button
            type="button"
            onClick={() =>
              navigate(RoutePaths.forgotPassword, { state: { email: email.trim() } })
            }
            className="ml-auto text-[12px] text-ink-3 hover:text-accent-text"
          >
            Forgot password?
          </button>
        </div>

        <button
          type="submit"
          disabled={submitting}
          className={cn(
            'w-full rounded-[12px] bg-accent p-[13px] text-center text-[13.5px] font-semibold text-accent-ink shadow-[0_6px_18px_-8px_var(--accent-line)] hover:brightness-95',
            submitting && 'pointer-events-none opacity-[.65]',
          )}
        >
          {submitting ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  );
}

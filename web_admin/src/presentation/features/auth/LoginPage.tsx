// Phase 0 placeholder. Phase 1 replaces this with the real form (RHF + Zod).

import { useEffect } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '@/presentation/stores/authStore';
import { RoutePaths } from '@/presentation/router/routePaths';
import { LoadingView } from '@/presentation/components/common/LoadingView';

export function LoginPage() {
  const { status, user } = useAuthStore();
  const location = useLocation();
  const from = (location.state as { from?: string } | null)?.from ?? RoutePaths.dashboard;

  useEffect(() => {
    document.title = 'Sign in · MAKI POS Admin';
  }, []);

  if (status === 'loading') return <LoadingView label="Restoring session…" />;
  if (status === 'signedIn' && user?.role === 'admin') {
    return <Navigate to={from} replace />;
  }

  return (
    <div className="space-y-tk-md">
      <h1 className="text-headingMedium text-light-text">MAKI POS Admin</h1>
      <p className="text-bodySmall text-light-text-secondary">
        Login form lands in phase 1 of the migration. For now, sign in via the existing Flutter
        web app — the session is shared automatically once you return here.
      </p>
    </div>
  );
}

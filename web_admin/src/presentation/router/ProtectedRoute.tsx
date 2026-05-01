// Wraps the AdminShell and enforces auth + per-route permission checks.
// Mirrors the redirect logic in lib/config/router/web_router.dart: unauth →
// /login, non-admin → /access-denied, no permission → /access-denied.

import { Navigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '@/presentation/stores/authStore';
import { canAccess, getRedirectPath } from './routeGuards';
import { RoutePaths } from './routePaths';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import type { ReactNode } from 'react';

export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { status, user } = useAuthStore();
  const location = useLocation();

  if (status === 'loading') return <LoadingView label="Restoring session…" />;

  if (status === 'signedOut') {
    return <Navigate to={RoutePaths.login} replace state={{ from: location.pathname }} />;
  }

  // Web admin currently restricts to admin role; mirror web_router.dart.
  if (user && user.role !== 'admin') {
    return <Navigate to={RoutePaths.accessDenied} replace />;
  }

  if (!canAccess(location.pathname, user)) {
    return <Navigate to={getRedirectPath(user, location.pathname)} replace />;
  }

  return <>{children}</>;
}

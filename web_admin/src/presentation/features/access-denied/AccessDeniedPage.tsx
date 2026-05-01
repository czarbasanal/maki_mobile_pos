import { useNavigate } from 'react-router-dom';
import { ShieldOff } from 'lucide-react';
import { useAuthRepo } from '@/infrastructure/di/container';
import { RoutePaths } from '@/presentation/router/routePaths';

export function AccessDeniedPage() {
  const authRepo = useAuthRepo();
  const navigate = useNavigate();

  const onSignOut = async () => {
    await authRepo.signOut();
    navigate(RoutePaths.login, { replace: true });
  };

  return (
    <div className="space-y-tk-md text-center">
      <div className="flex justify-center text-error">
        <ShieldOff className="h-10 w-10" />
      </div>
      <h1 className="text-headingMedium text-light-text">Access denied</h1>
      <p className="text-bodyMedium text-light-text-secondary">
        Your account does not have permission to use the web admin. Sign in with an admin account
        to continue.
      </p>
      <button
        type="button"
        onClick={onSignOut}
        className="rounded-md bg-brand-slate px-tk-md py-tk-sm text-bodyMedium font-medium text-white hover:bg-primary-dark"
      >
        Sign out
      </button>
    </div>
  );
}

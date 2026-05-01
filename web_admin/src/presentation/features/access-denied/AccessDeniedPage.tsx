import { useNavigate } from 'react-router-dom';
import { NoSymbolIcon } from '@heroicons/react/24/outline';
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
      <div className="flex justify-center text-light-text-secondary">
        <NoSymbolIcon className="h-10 w-10" />
      </div>
      <h1 className="text-headingMedium font-semibold text-light-text">Access denied</h1>
      <p className="text-bodySmall text-light-text-secondary">
        Your account does not have permission to use the web admin. Sign in with an admin account
        to continue.
      </p>
      <button
        type="button"
        onClick={onSignOut}
        className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-medium text-light-background hover:bg-primary-dark"
      >
        Sign out
      </button>
    </div>
  );
}

// Shared header for settings sub-pages — title + back link.

import { Link } from 'react-router-dom';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';

export function PageHeader({
  title,
  description,
  backTo = RoutePaths.settings,
  backLabel = 'Settings',
}: {
  title: string;
  description?: string;
  backTo?: string;
  backLabel?: string;
}) {
  return (
    <header className="space-y-tk-sm">
      <Link
        to={backTo}
        className="inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
      >
        <ArrowLeftIcon className="h-3.5 w-3.5" />
        {backLabel}
      </Link>
      <div>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          {title}
        </h1>
        {description ? (
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">{description}</p>
        ) : null}
      </div>
    </header>
  );
}

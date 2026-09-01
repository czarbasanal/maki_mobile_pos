// Shared header for settings/HR sub-pages — a back link, plus an optional
// title + description. The title now usually lives in the shell's fixed
// header (via the route's `handle`); omit `title` here to render just the
// back-link affordance and avoid showing it twice.

import { Link } from 'react-router-dom';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';

export function PageHeader({
  title,
  description,
  backTo = RoutePaths.settings,
  backLabel = 'Settings',
}: {
  title?: string;
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
      {title ? (
        <div>
          <h2 className="text-headingMedium font-semibold tracking-tight text-light-text">
            {title}
          </h2>
          {description ? (
            <p className="mt-tk-xs text-bodySmall text-light-text-secondary">{description}</p>
          ) : null}
        </div>
      ) : null}
    </header>
  );
}

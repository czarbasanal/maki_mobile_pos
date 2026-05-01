import { ExclamationCircleIcon } from '@heroicons/react/24/outline';

export function ErrorView({
  title = 'Something went wrong',
  message,
  onRetry,
}: {
  title?: string;
  message?: string;
  onRetry?: () => void;
}) {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-tk-sm p-tk-xl text-center">
      <ExclamationCircleIcon className="h-8 w-8 text-error" />
      <h3 className="text-headingSmall font-semibold text-light-text">{title}</h3>
      {message ? <p className="text-bodySmall text-light-text-secondary">{message}</p> : null}
      {onRetry ? (
        <button
          type="button"
          onClick={onRetry}
          className="mt-tk-sm rounded-md border border-light-hairline bg-light-card px-tk-md py-tk-xs text-bodySmall font-medium text-light-text hover:bg-light-subtle"
        >
          Try again
        </button>
      ) : null}
    </div>
  );
}

import { AlertCircle } from 'lucide-react';

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
      <AlertCircle className="h-8 w-8 text-error" />
      <h3 className="text-headingSmall text-light-text">{title}</h3>
      {message ? <p className="text-bodyMedium text-light-text-secondary">{message}</p> : null}
      {onRetry ? (
        <button
          type="button"
          onClick={onRetry}
          className="mt-tk-sm rounded-md bg-brand-slate px-tk-md py-tk-sm text-bodySmall font-medium text-white hover:bg-primary-dark"
        >
          Try again
        </button>
      ) : null}
    </div>
  );
}

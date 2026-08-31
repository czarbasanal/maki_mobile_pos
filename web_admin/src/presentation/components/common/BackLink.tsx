import { useLocation, useNavigate } from 'react-router-dom';

/**
 * Back navigation for a page reachable from more than one place.
 *
 * A hardcoded destination is correct only where a page has exactly one entry
 * point — a checkout is always reached from the cart, so "← Back to cart" is
 * honest. It is wrong for a detail page: a sale is opened from the dashboard,
 * the day-sales list, a report and the void queue, and a receiving from both
 * the receiving dashboard and its history. Sending all of them to one fixed
 * page drops most visitors somewhere they have never been.
 *
 * [fallback] is used only when there is nothing to go back to. React Router
 * marks the first entry of a session 'default', which is what a deep link, a
 * bookmark or a refresh looks like.
 */
export function BackLink({
  fallback,
  label = '← Back',
  className,
}: {
  fallback: string;
  label?: string;
  className?: string;
}) {
  const navigate = useNavigate();
  const location = useLocation();
  const canGoBack = location.key !== 'default';

  return (
    <button
      type="button"
      onClick={() => (canGoBack ? navigate(-1) : navigate(fallback))}
      className={className ?? 'text-bodySmall text-light-text-secondary hover:underline'}
    >
      {label}
    </button>
  );
}

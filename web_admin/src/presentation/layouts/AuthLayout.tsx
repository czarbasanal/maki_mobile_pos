// Bare layout for /login and /access-denied — no sidebar, centered card.

import { Outlet } from 'react-router-dom';

export function AuthLayout() {
  return (
    <div className="flex h-full w-full items-center justify-center bg-light-surface p-tk-lg">
      <div className="w-full max-w-md rounded-lg border border-light-border bg-light-card p-tk-xl shadow-sm">
        <Outlet />
      </div>
    </div>
  );
}

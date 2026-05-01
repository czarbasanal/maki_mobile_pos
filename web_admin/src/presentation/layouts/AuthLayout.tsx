// Bare layout for /login and /access-denied — no sidebar, centered card.

import { Outlet } from 'react-router-dom';

export function AuthLayout() {
  return (
    <div className="flex h-full w-full items-center justify-center bg-light-background p-tk-lg">
      <div className="w-full max-w-md">
        <Outlet />
      </div>
    </div>
  );
}

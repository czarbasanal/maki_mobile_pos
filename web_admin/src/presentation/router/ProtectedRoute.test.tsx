// Which roles may enter the web shell at all. Until 2026-08-24 this was
// admin-only; cashiers now get in with mobile-parity privileges. Staff stays
// out until asked for.
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom';
import { ProtectedRoute } from './ProtectedRoute';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities/User';

const base: User = {
  id: 'u1',
  email: 'x@shop.test',
  displayName: 'X',
  role: UserRole.admin,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
};

function Probe() {
  return <div>APP SHELL at {useLocation().pathname}</div>;
}

function harness(path: string, user: User | null) {
  useAuthStore.setState({ status: user ? 'signedIn' : 'signedOut', user });
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path="/login" element={<div>LOGIN PAGE</div>} />
        <Route path="/access-denied" element={<div>ACCESS DENIED PAGE</div>} />
        <Route
          path="*"
          element={
            <ProtectedRoute>
              <Probe />
            </ProtectedRoute>
          }
        />
      </Routes>
    </MemoryRouter>,
  );
}

describe('ProtectedRoute — web role allowlist', () => {
  it('admits an admin', () => {
    harness('/pos', base);
    expect(screen.getByText(/APP SHELL/)).toBeInTheDocument();
  });

  it('admits a cashier (mobile-parity privileges)', () => {
    harness('/pos', { ...base, role: UserRole.cashier });
    expect(screen.getByText(/APP SHELL/)).toBeInTheDocument();
  });

  it('keeps staff out for now', () => {
    harness('/pos', { ...base, role: UserRole.staff });
    expect(screen.getByText('ACCESS DENIED PAGE')).toBeInTheDocument();
  });

  it('sends the signed-out to login', () => {
    harness('/pos', null);
    expect(screen.getByText('LOGIN PAGE')).toBeInTheDocument();
  });

  it('still bounces an allowed role off a route it lacks permission for', () => {
    harness('/hr/payroll', { ...base, role: UserRole.cashier });
    // getRedirectPath sends permission misses to the dashboard route.
    expect(screen.getByText('APP SHELL at /')).toBeInTheDocument();
  });
});

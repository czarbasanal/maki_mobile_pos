// Per-row permission gating — until cashiers gained web access every row
// could assume an admin viewer; now each Administration row shows only to
// holders of its route's permission.
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider } from '@/infrastructure/di/container';
import { SettingsPage } from './SettingsPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';

function harness(role: UserRole) {
  useAuthStore.setState({
    user: {
      id: 'u1', email: 'a@shop.test', displayName: 'Tester', role, isActive: true,
    } as never,
    status: 'signedIn',
  });
  const qc = new QueryClient();
  render(
    <DiProvider>
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <SettingsPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('SettingsPage — row permissions', () => {
  it('cashier: profile + lists + mechanics + about, nothing admin-only', () => {
    harness(UserRole.cashier);
    for (const row of ['Display name', 'Change password', 'Manage lists', 'Mechanics', 'About']) {
      expect(screen.getByText(row)).toBeInTheDocument();
    }
    for (const row of ['User management', 'Activity logs', 'Cost code settings']) {
      expect(screen.queryByText(row)).not.toBeInTheDocument();
    }
  });

  it('admin keeps every row', () => {
    harness(UserRole.admin);
    for (const row of [
      'User management',
      'Activity logs',
      'Cost code settings',
      'Manage lists',
      'Mechanics',
      'About',
    ]) {
      expect(screen.getByText(row)).toBeInTheDocument();
    }
  });
});

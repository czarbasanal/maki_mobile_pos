// Daily-only lock for cashier (mobile parity) — the picker gives way to the
// amber lock notice and the query clamps to today.
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { LaborReportPage } from './LaborReportPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';

function webUser(role: UserRole): User {
  return {
    id: `u-${role}`,
    email: `${role}@shop.test`,
    displayName: `${role} user`,
    role,
    isActive: true,
    phoneNumber: null,
    photoUrl: null,
    createdAt: new Date('2026-01-01'),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    lastLoginAt: null,
  };
}

function harness(role: UserRole) {
  useAuthStore.setState({ status: 'signedIn', user: webUser(role) });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const saleRepo: Partial<Container['saleRepo']> = {
    list: vi.fn().mockResolvedValue([]),
  };
  render(
    <DiProvider override={{ saleRepo: saleRepo as Container['saleRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <LaborReportPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { saleRepo };
}

describe('LaborReportPage — cashier daily lock', () => {
  it('locks a cashier to today with the labor lock notice, no picker', async () => {
    harness(UserRole.cashier);
    await screen.findByText(
      "Showing today's labor only. Contact an admin for historical reports.",
    );
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();
  });

  it('admin keeps the range picker', async () => {
    harness(UserRole.admin);
    await screen.findByText('Total Labor');
    expect(screen.getByRole('combobox')).toBeInTheDocument();
  });
});

// Hub tiles are permission-filtered since cashiers gained web access —
// mobile parity: cashiers get Sales + Labor; Profit and Price changes are
// cost-facing (admin).
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { ReportsHubPage } from './ReportsHubPage';
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
  return render(
    <MemoryRouter>
      <ReportsHubPage />
    </MemoryRouter>,
  );
}

describe('ReportsHubPage — permission-filtered tiles', () => {
  it('admin sees all four reports', () => {
    harness(UserRole.admin);
    for (const title of ['Sales report', 'Profit report', 'Labor report', 'Price changes']) {
      expect(screen.getByText(title)).toBeInTheDocument();
    }
  });

  it('cashier sees only Sales and Labor (mobile parity)', () => {
    harness(UserRole.cashier);
    expect(screen.getByText('Sales report')).toBeInTheDocument();
    expect(screen.getByText('Labor report')).toBeInTheDocument();
    expect(screen.queryByText('Profit report')).not.toBeInTheDocument();
    expect(screen.queryByText('Price changes')).not.toBeInTheDocument();
  });
});

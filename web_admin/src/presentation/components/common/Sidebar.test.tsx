import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities/User';
import { useAuthStore } from '@/presentation/stores/authStore';
import { Sidebar } from './Sidebar';

const admin: User = {
  id: 'u1',
  email: 'admin@shop.test',
  displayName: 'Admin',
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

function harness(initialPath: string) {
  useAuthStore.setState({ user: admin });
  const authRepo = { signOut: vi.fn() } as unknown as Container['authRepo'];
  return render(
    <DiProvider override={{ authRepo }}>
      <MemoryRouter initialEntries={[initialPath]}>
        <Sidebar />
      </MemoryRouter>
    </DiProvider>,
  );
}

describe('Sidebar — Inventory dropdown', () => {
  it('hides Reorder and Price History while outside the inventory subtree', () => {
    harness('/pos');
    expect(screen.getByRole('link', { name: /inventory/i })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /reorder/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /price history/i })).not.toBeInTheDocument();
  });

  it('shows the sub-items automatically anywhere in the inventory subtree', () => {
    harness('/inventory/reorder');
    expect(screen.getByRole('link', { name: /reorder/i })).toHaveAttribute(
      'href',
      '/inventory/reorder',
    );
    expect(screen.getByRole('link', { name: /price history/i })).toHaveAttribute(
      'href',
      '/inventory/price-history',
    );
  });

  it('chevron expands and collapses the group without navigating', async () => {
    harness('/pos');
    await userEvent.click(screen.getByRole('button', { name: /expand inventory/i }));
    expect(screen.getByRole('link', { name: /reorder/i })).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /collapse inventory/i }));
    expect(screen.queryByRole('link', { name: /reorder/i })).not.toBeInTheDocument();
  });
});

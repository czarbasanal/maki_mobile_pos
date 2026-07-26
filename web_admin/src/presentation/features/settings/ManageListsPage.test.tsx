import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Category } from '@/domain/entities';
import { ManageListsPage } from './ManageListsPage';

function harness(categories: Category[]) {
  useAuthStore.setState({
    user: {
      id: 'admin-1',
      email: 'a@shop.test',
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
    },
    status: 'signedIn',
  });
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const categoryRepo = {
    watchAll: vi.fn((_kind: unknown, cb: (cats: Category[]) => void) => {
      cb(categories);
      return () => {};
    }),
    list: vi.fn(async () => categories),
    create: vi.fn(),
    update: vi.fn(),
  } as unknown as Container['categoryRepo'];
  render(
    <DiProvider override={{ categoryRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <ManageListsPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { categoryRepo };
}

function category(o: Partial<Category> = {}): Category {
  return {
    id: 'c1',
    name: 'Filters',
    isActive: true,
    createdAt: new Date('2026-01-01'),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    ...o,
  };
}

describe('ManageListsPage — product category codes', () => {
  it('renders the Code128 code as a mono chip next to a coded product category', () => {
    harness([category({ code: '0001' })]);

    expect(screen.getByText('Filters')).toBeInTheDocument();
    const chip = screen.getByText('0001');
    expect(chip).toBeInTheDocument();
    expect(chip.className).toContain('font-mono');
  });

  it('renders no chip for a category without a code', () => {
    harness([category({ code: undefined })]);

    expect(screen.getByText('Filters')).toBeInTheDocument();
    expect(screen.queryByText(/^\d{4}$/)).not.toBeInTheDocument();
  });
});

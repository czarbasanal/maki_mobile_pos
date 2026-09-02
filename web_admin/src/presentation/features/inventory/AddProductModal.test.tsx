// /inventory/add is a MODAL over the list now, not a separate page: the
// list stays mounted underneath, the dialog hosts the same embedded form the
// edit drawer uses, and closing it routes back to /inventory.
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Outlet, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { AddProductModal } from './AddProductModal';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import { defaultCostCode } from '@/domain/entities/CostCode';

function harness() {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.c', displayName: 'Czar', role: UserRole.admin, isActive: true } as never,
    status: 'signedIn',
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (_kind, cb) => {
      cb([]);
      return () => {};
    },
    peekNextSequence: vi.fn().mockResolvedValue(1),
  };
  const supplierRepo: Partial<Container['supplierRepo']> = {
    watchAll: (cb) => {
      cb([]);
      return () => {};
    },
  };
  const costCodeRepo: Partial<Container['costCodeRepo']> = {
    watch: (cb) => {
      cb(defaultCostCode);
      return () => {};
    },
  };
  return render(
    <DiProvider
      override={
        {
          categoryRepo,
          supplierRepo,
          costCodeRepo,
        } as unknown as Container
      }
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/inventory/add']}>
          <Routes>
            <Route
              path="/inventory"
              element={
                <div>
                  <span>LIST UNDERNEATH</span>
                  <Outlet />
                </div>
              }
            >
              <Route path="add" element={<AddProductModal />} />
            </Route>
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('AddProductModal', () => {
  it('renders the embedded product form in a dialog over the list', () => {
    harness();
    expect(screen.getByText('LIST UNDERNEATH')).toBeInTheDocument();
    expect(screen.getByText('New product')).toBeInTheDocument();
    // The embedded form's sections are inside the dialog.
    expect(screen.getByText('Identity')).toBeInTheDocument();
    expect(screen.getByText('Pricing')).toBeInTheDocument();
  });

  it('closing the dialog routes back to the list', async () => {
    harness();
    await userEvent.keyboard('{Escape}');
    expect(screen.queryByText('New product')).not.toBeInTheDocument();
    expect(screen.getByText('LIST UNDERNEATH')).toBeInTheDocument();
  });
});

// Add/edit supplier is a modal over the directory now, and the deactivate
// flow (the feature's only destructive action) lives inside the edit form.
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Outlet, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { SupplierModal } from './SupplierModal';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole, TransactionType } from '@/domain/enums';
import type { Supplier } from '@/domain/entities';

const supplier: Supplier = {
  id: 's1',
  name: 'Boss Atan Argao',
  address: null,
  contactPerson: null,
  contactNumber: null,
  alternativeNumber: null,
  email: null,
  transactionType: TransactionType.cash,
  isActive: true,
  notes: null,
  createdAt: new Date(),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  productCount: 0,
  totalInventoryValue: 0,
};

function harness(entry: string, deactivateFn = vi.fn(async () => {})) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.c', displayName: 'C', role: UserRole.admin, isActive: true } as never,
    status: 'signedIn',
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const supplierRepo: Partial<Container['supplierRepo']> = {
    getById: vi.fn(async () => supplier),
    deactivate: deactivateFn,
  };
  const activityLogRepo: Partial<Container['activityLogRepo']> = {
    log: vi.fn(async () => {}),
  };
  render(
    <DiProvider
      override={{
        supplierRepo: supplierRepo as Container['supplierRepo'],
        activityLogRepo: activityLogRepo as Container['activityLogRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[entry]}>
          <Routes>
            <Route
              path="/suppliers"
              element={
                <div>
                  <span>DIRECTORY UNDERNEATH</span>
                  <Outlet />
                </div>
              }
            >
              <Route path="add" element={<SupplierModal />} />
              <Route path="edit/:id" element={<SupplierModal />} />
            </Route>
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return deactivateFn;
}

describe('SupplierModal', () => {
  beforeEach(() => {
    useAuthStore.setState({ user: null, status: 'signedOut' } as never);
  });

  it('add mode renders the embedded form in a dialog over the directory', () => {
    harness('/suppliers/add');
    expect(screen.getByText('DIRECTORY UNDERNEATH')).toBeInTheDocument();
    expect(screen.getByText('New supplier')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Create supplier' })).toBeInTheDocument();
    // No deactivate offered while creating.
    expect(screen.queryByRole('button', { name: /deactivate/i })).not.toBeInTheDocument();
  });

  it('edit mode offers Deactivate; confirming fires the mutation and closes the modal', async () => {
    const deactivateFn = harness('/suppliers/edit/s1');
    expect(await screen.findByText('Edit supplier')).toBeInTheDocument();

    await userEvent.click(await screen.findByRole('button', { name: 'Deactivate supplier' }));
    expect(screen.getByText('Deactivate supplier?')).toBeInTheDocument();
    expect(screen.getByText(/keeps referencing it/)).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Deactivate' }));
    expect(deactivateFn).toHaveBeenCalledWith('s1', 'u1');
    // Navigated back to the directory — the modal route unmounted.
    expect(screen.queryByText('Edit supplier')).not.toBeInTheDocument();
    expect(screen.getByText('DIRECTORY UNDERNEATH')).toBeInTheDocument();
  });

  it('closing the dialog routes back to the directory', async () => {
    harness('/suppliers/add');
    await userEvent.keyboard('{Escape}');
    expect(screen.queryByText('New supplier')).not.toBeInTheDocument();
    expect(screen.getByText('DIRECTORY UNDERNEATH')).toBeInTheDocument();
  });
});

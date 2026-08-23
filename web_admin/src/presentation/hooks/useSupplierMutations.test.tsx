// Supplier mutations were the one web write path with no activity logging —
// mobile logs supplier create/update/deactivate, so the same edit was audited
// from a phone and invisible from the web admin. Same DiProvider template as
// useExpenses.test.tsx.
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import {
  useCreateSupplier,
  useDeactivateSupplier,
  useUpdateSupplier,
} from './useSupplierMutations';
import type { Supplier } from '@/domain/entities';
import type { ReactNode } from 'react';

function signIn() {
  useAuthStore.setState({
    user: {
      id: 'u1', email: 'a@b.co', displayName: 'Tester',
      role: UserRole.admin, isActive: true,
    } as never,
    status: 'signedIn',
  });
}

function supplier(over: Partial<Supplier> = {}): Supplier {
  return {
    id: 's1', name: 'Acme Parts', address: null, contactPerson: null,
    contactNumber: null, alternativeNumber: null, email: null,
    transactionType: 'cash' as never, notes: null, isActive: true,
    createdAt: new Date('2026-01-01'), updatedAt: null,
    createdBy: 'u1', updatedBy: 'u1',
    productCount: 0, totalInventoryValue: 0,
    ...over,
  };
}

function wrap(
  supplierRepo: Partial<Container['supplierRepo']>,
  log: ReturnType<typeof vi.fn>,
) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const activityLogRepo = { log } as unknown as Container['activityLogRepo'];
  return ({ children }: { children: ReactNode }) => (
    <DiProvider
      override={{
        supplierRepo: supplierRepo as Container['supplierRepo'],
        activityLogRepo,
      }}
    >
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </DiProvider>
  );
}

describe('supplier mutations write activity logs', () => {
  beforeEach(() => signIn());

  it('creating a supplier logs a supplier entry naming it', async () => {
    const log = vi.fn().mockResolvedValue(undefined);
    const create = vi.fn().mockResolvedValue(supplier());
    const { result } = renderHook(() => useCreateSupplier(), {
      wrapper: wrap({ create }, log),
    });

    await act(async () => {
      await result.current.mutateAsync({
        name: 'Acme Parts', address: null, contactPerson: null,
        contactNumber: null, alternativeNumber: null, email: null,
        transactionType: 'cash' as never, notes: null,
      });
    });

    await waitFor(() => expect(log).toHaveBeenCalled());
    const entry = log.mock.calls[0][0];
    expect(entry.type).toBe('supplier');
    expect(entry.action).toContain('Acme Parts');
    expect(entry.entityId).toBe('s1');
  });

  it('updating a supplier logs a supplier entry', async () => {
    const log = vi.fn().mockResolvedValue(undefined);
    const update = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useUpdateSupplier(), {
      wrapper: wrap({ update }, log),
    });

    await act(async () => {
      await result.current.mutateAsync({ id: 's1', name: 'Acme Parts' });
    });

    await waitFor(() => expect(log).toHaveBeenCalled());
    const entry = log.mock.calls[0][0];
    expect(entry.type).toBe('supplier');
    expect(entry.action.toLowerCase()).toContain('updated');
    expect(entry.entityId).toBe('s1');
  });

  it('deactivating a supplier logs a supplier entry', async () => {
    const log = vi.fn().mockResolvedValue(undefined);
    const deactivate = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useDeactivateSupplier(), {
      wrapper: wrap({ deactivate }, log),
    });

    await act(async () => {
      await result.current.mutateAsync('s1');
    });

    await waitFor(() => expect(log).toHaveBeenCalled());
    const entry = log.mock.calls[0][0];
    expect(entry.type).toBe('supplier');
    expect(entry.action.toLowerCase()).toContain('deactivated');
    expect(entry.entityId).toBe('s1');
  });
});

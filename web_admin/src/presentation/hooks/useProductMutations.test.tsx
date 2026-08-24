// Carried forward from Task 13's review: no test pinned the
// `actor.role === UserRole.admin` -> `includeSellingOptions` wiring inside
// useUpdateProduct's mutationFn. It was inert at the time (no UI could
// populate `patch.sellingOptions`); Task 15 ships that UI, so the wiring is
// live now and needs its own test.
//
// Three roles, not one: a single-sided assertion (e.g. "admin => true")
// can't distinguish correct role-based wiring from a hardcoded `true`, and a
// hardcoded `true` here would be a price-editing back door for non-admins —
// sellingOptions entries set the per-piece selling price.
import type { ReactNode } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useUpdateProduct } from './useProductMutations';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';

function signIn(role: UserRole) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
    status: 'signedIn',
  });
}

function wrapperFor(productRepo: Partial<Container['productRepo']>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];
  return function Wrapper({ children }: { children: ReactNode }) {
    return (
      <DiProvider
        override={{ productRepo: productRepo as Container['productRepo'], activityLogRepo }}
      >
        <QueryClientProvider client={qc}>{children}</QueryClientProvider>
      </DiProvider>
    );
  };
}

async function runUpdate(role: UserRole, update: ReturnType<typeof vi.fn>) {
  signIn(role);
  // The name-only (cashier) path re-reads the doc to rebase — stub the read.
  const getById = vi.fn().mockResolvedValue({
    id: 'p1', sku: 'SKU1', name: 'X', costCode: null, cost: 1, price: 2,
    quantity: 0, reorderLevel: 0, unit: 'pcs', supplierId: null,
    supplierName: null, isActive: true, createdAt: new Date('2026-01-01'),
    updatedAt: null, createdBy: null, updatedBy: null, createdByName: null,
    updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcodes: [], sellingOptions: [], category: null,
    imageUrl: null, notes: null,
  });
  const { result } = renderHook(() => useUpdateProduct(), {
    wrapper: wrapperFor({ update, getById }),
  });
  await result.current.mutateAsync({
    id: 'p1',
    oldSku: 'SKU1',
    oldBarcodes: [],
    patch: { name: 'X', sellingOptions: [{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }] },
    priceChange: null,
  });
  await waitFor(() => expect(update).toHaveBeenCalled());
}

describe('useUpdateProduct — includeSellingOptions role wiring', () => {
  it('passes includeSellingOptions: true for an admin actor', async () => {
    const update = vi.fn().mockResolvedValue(undefined);
    await runUpdate(UserRole.admin, update);
    const [, , , includeSellingOptions] = update.mock.calls[0];
    expect(includeSellingOptions).toBe(true);
  });

  it('passes includeSellingOptions: false for a staff actor', async () => {
    const update = vi.fn().mockResolvedValue(undefined);
    await runUpdate(UserRole.staff, update);
    const [, , , includeSellingOptions] = update.mock.calls[0];
    expect(includeSellingOptions).toBe(false);
  });

  it('passes includeSellingOptions: false for a cashier actor', async () => {
    const update = vi.fn().mockResolvedValue(undefined);
    await runUpdate(UserRole.cashier, update);
    const [, , , includeSellingOptions] = update.mock.calls[0];
    expect(includeSellingOptions).toBe(false);
  });
});

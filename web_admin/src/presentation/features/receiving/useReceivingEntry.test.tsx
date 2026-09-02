import { describe, expect, it, vi, beforeEach } from 'vitest';
import { renderHook, waitFor, act } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useReceivingEntry } from './useReceivingEntry';
import { useAuthStore } from '@/presentation/stores/authStore';
import { RECEIVING_CONFLICT_MESSAGE } from '@/domain/receiving/draftConcurrency';
import type { Receiving } from '@/domain/entities';
import type { ReactNode } from 'react';

const draft = (o: Partial<Receiving> = {}): Receiving => ({
  id: 'rcv1',
  referenceNumber: 'RCV-20260829-001',
  supplierId: null,
  supplierName: null,
  items: [],
  totalCost: 0,
  totalQuantity: 0,
  status: 'draft',
  notes: null,
  createdAt: new Date('2026-08-29'),
  completedAt: null,
  createdBy: 'u1',
  createdByName: 'Czar',
  completedBy: null,
  version: 4,
  ...o,
});

function wrap(receivingRepo: Partial<Container['receivingRepo']>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={qc}>
      <DiProvider
        override={
          {
            receivingRepo,
            productRepo: { watchAll: () => () => {} },
            supplierRepo: { watchAll: () => () => {} },
            activityLogRepo: { create: vi.fn() },
          } as unknown as Container
        }
      >
        <MemoryRouter initialEntries={['/receiving/rcv1']}>
          <Routes>
            <Route path="/receiving/:id" element={<>{children}</>} />
          </Routes>
        </MemoryRouter>
      </DiProvider>
    </QueryClientProvider>
  );
}

describe('useReceivingEntry — concurrent draft edits', () => {
  beforeEach(() => {
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.c', displayName: 'Czar', role: 'admin', isActive: true } as never,
    });
  });

  it('saves against the version it loaded, so a stale write can be refused', async () => {
    const update = vi.fn(async () => {});
    const { result } = renderHook(() => useReceivingEntry(), {
      wrapper: wrap({
        getById: vi.fn(async () => draft({ version: 4 })),
        update,
      } as Partial<Container['receivingRepo']>),
    });

    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    await act(async () => { await result.current.saveDraft(); });

    expect(update).toHaveBeenCalledWith(
      'rcv1',
      expect.anything(),
      'u1',
      4,
    );
  });

  it('surfaces the conflict instead of failing silently', async () => {
    const update = vi.fn(async () => { throw new Error(RECEIVING_CONFLICT_MESSAGE); });
    const { result } = renderHook(() => useReceivingEntry(), {
      wrapper: wrap({
        getById: vi.fn(async () => draft()),
        update,
      } as Partial<Container['receivingRepo']>),
    });

    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    await act(async () => { await result.current.saveDraft(); });

    // The whole point: the operator is told, rather than believing it saved.
    expect(result.current.error).toBe(RECEIVING_CONFLICT_MESSAGE);
  });

  it('does not advance its version when the save was refused', async () => {
    // A refused save changed nothing on the server, so a retry must still
    // present the version this page loaded — bumping on failure would make
    // the second attempt look current and overwrite the other device after all.
    const update = vi
      .fn()
      .mockRejectedValueOnce(new Error(RECEIVING_CONFLICT_MESSAGE))
      .mockResolvedValueOnce(undefined);
    const { result } = renderHook(() => useReceivingEntry(), {
      wrapper: wrap({
        getById: vi.fn(async () => draft({ version: 4 })),
        update,
      } as Partial<Container['receivingRepo']>),
    });

    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    await act(async () => { await result.current.saveDraft(); });
    await act(async () => { await result.current.saveDraft(); });

    expect(update.mock.calls[0][3]).toBe(4);
    expect(update.mock.calls[1][3]).toBe(4);
  });
});

describe('useReceivingEntry — line editing', () => {
  beforeEach(() => {
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.c', displayName: 'Czar', role: 'admin', isActive: true } as never,
    });
  });

  const productFixture = {
    id: 'p1', sku: '00220004', name: 'Beast Tire', category: 'Tires', unit: 'pcs',
    cost: 1200, price: 1600, quantity: 5, reorderLevel: 2, costCode: 'AB',
    barcodes: [], sellingOptions: [], supplierId: null, supplierName: null,
    baseSku: null, variationNumber: null, isActive: true, imageUrl: null, notes: null,
    searchKeywords: [], createdAt: new Date(), updatedAt: null,
    createdBy: 'u1', updatedBy: 'u1', createdByName: 'Czar', updatedByName: 'Czar',
  };

  function mounted() {
    return renderHook(() => useReceivingEntry(), {
      wrapper: wrap({
        getById: vi.fn(async () => draft()),
        update: vi.fn(async () => {}),
      } as Partial<Container['receivingRepo']>),
    });
  }

  it('addExisting stamps the entered unitPrice on the line', async () => {
    const { result } = mounted();
    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    act(() => result.current.addExisting(productFixture as never, 4, 1312, 1680));
    expect(result.current.lines[0]).toMatchObject({ quantity: 4, unitCost: 1312, unitPrice: 1680 });
  });

  it('updateExisting rewrites qty/cost/price in place, keeping the line id', async () => {
    const { result } = mounted();
    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    act(() => result.current.addExisting(productFixture as never, 4, 1312, null));
    const id = result.current.lines[0].id;
    act(() => result.current.updateExisting(id, { quantity: 6, unitCost: 1350, unitPrice: 1700 }));
    expect(result.current.lines).toHaveLength(1);
    expect(result.current.lines[0]).toMatchObject({
      id, quantity: 6, unitCost: 1350, unitPrice: 1700, productId: 'p1',
    });
  });

  it('updateNew rebuilds a pending-new line from the edited spec, keeping the line id', async () => {
    const { result } = mounted();
    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    const spec = {
      name: 'Squid', sku: '00090001', autoGenerateSku: true, category: 'Fish', unit: 'kg',
      cost: 90, price: 130, quantity: 3, reorderLevel: 1, autoSkuCategoryCode: '0009',
      barcodes: [], notes: null, sellingOptions: [],
    };
    act(() => result.current.addNew(spec));
    const id = result.current.lines[0].id;
    act(() => result.current.updateNew(id, { ...spec, name: 'Squid Large', cost: 95, price: 140, quantity: 5 }));
    expect(result.current.lines).toHaveLength(1);
    expect(result.current.lines[0]).toMatchObject({ id, name: 'Squid Large', unitCost: 95, quantity: 5 });
    expect(result.current.lines[0].pendingNewProduct).toMatchObject({ price: 140 });
  });
});

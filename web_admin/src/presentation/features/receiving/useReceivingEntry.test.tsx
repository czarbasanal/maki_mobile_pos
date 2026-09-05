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
  invoiceNumber: null,
  receivedOn: null,
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

describe('useReceivingEntry — direct-add line model', () => {
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

  it('addExisting appends a fresh line seeded from the product, qty 1 and no price lock', async () => {
    const { result } = mounted();
    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    act(() => result.current.addExisting(productFixture as never));
    expect(result.current.lines).toHaveLength(1);
    expect(result.current.lines[0]).toMatchObject({
      productId: 'p1', sku: '00220004', quantity: 1, unitCost: 1200, unitPrice: null,
    });
  });

  it('a second addExisting for the same product increments the existing line instead of appending', async () => {
    const { result } = mounted();
    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    act(() => result.current.addExisting(productFixture as never));
    act(() => result.current.addExisting(productFixture as never));
    expect(result.current.lines).toHaveLength(1);
    expect(result.current.lines[0].quantity).toBe(2);
  });

  it('addExisting clears the search text (scanner-friendly)', async () => {
    const { result } = mounted();
    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    act(() => result.current.setSearch('beast'));
    act(() => result.current.addExisting(productFixture as never));
    expect(result.current.search).toBe('');
  });

  it('updateLine rewrites quantity in place, floored at 1', async () => {
    const { result } = mounted();
    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    act(() => result.current.addExisting(productFixture as never));
    const id = result.current.lines[0].id;
    act(() => result.current.updateLine(id, { quantity: 6 }));
    expect(result.current.lines[0].quantity).toBe(6);
    act(() => result.current.updateLine(id, { quantity: 0 }));
    expect(result.current.lines[0].quantity).toBe(1);
  });

  it('updateLine keeps a typed unitPrice while the cost still differs from the catalog', async () => {
    const { result } = mounted();
    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    act(() => result.current.addExisting(productFixture as never));
    const id = result.current.lines[0].id;
    act(() => result.current.updateLine(id, { unitCost: 1350 }));
    act(() => result.current.updateLine(id, { unitPrice: 1700 }));
    expect(result.current.lines[0]).toMatchObject({ unitCost: 1350, unitPrice: 1700 });
  });

  it('updateLine resets unitPrice to null the moment the cost lands back at the catalog value — exactly confirmExisting semantics, now inline', async () => {
    const { result } = mounted();
    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    act(() => result.current.addExisting(productFixture as never));
    const id = result.current.lines[0].id;
    act(() => result.current.updateLine(id, { unitCost: 1350 }));
    act(() => result.current.updateLine(id, { unitPrice: 1700 }));
    act(() => result.current.updateLine(id, { unitCost: 1200 })); // back to catalog cost
    expect(result.current.lines[0]).toMatchObject({ unitCost: 1200, unitPrice: null });
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

describe('useReceivingEntry — invoice/received-on meta fields', () => {
  beforeEach(() => {
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.c', displayName: 'Czar', role: 'admin', isActive: true } as never,
    });
  });

  it('defaults receivedOn to today (shop calendar) and invoiceNumber to blank for a fresh entry', async () => {
    const create = vi.fn(async () => draft({ id: 'new1' }));
    const { result } = renderHook(() => useReceivingEntry(), {
      wrapper: ({ children }) => {
        const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
        return (
          <QueryClientProvider client={qc}>
            <DiProvider
              override={
                {
                  receivingRepo: {
                    nextReferenceNumber: vi.fn(async () => 'RCV-20260905-001'),
                    create,
                  },
                  productRepo: { watchAll: () => () => {} },
                  supplierRepo: { watchAll: () => () => {} },
                  activityLogRepo: { create: vi.fn() },
                } as unknown as Container
              }
            >
              <MemoryRouter initialEntries={['/receiving/new']}>
                <Routes><Route path="/receiving/new" element={<>{children}</>} /></Routes>
              </MemoryRouter>
            </DiProvider>
          </QueryClientProvider>
        );
      },
    });

    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260905-001'));
    expect(result.current.invoiceNumber).toBe('');
    expect(result.current.receivedOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('buildInput carries a trimmed invoiceNumber (null when blank) and the raw receivedOn string', async () => {
    const create = vi.fn(async () => draft({ id: 'new1' }));
    const { result } = renderHook(() => useReceivingEntry(), {
      wrapper: ({ children }) => {
        const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
        return (
          <QueryClientProvider client={qc}>
            <DiProvider
              override={
                {
                  receivingRepo: {
                    nextReferenceNumber: vi.fn(async () => 'RCV-20260905-001'),
                    create,
                  },
                  productRepo: { watchAll: () => () => {} },
                  supplierRepo: { watchAll: () => () => {} },
                  activityLogRepo: { create: vi.fn() },
                } as unknown as Container
              }
            >
              <MemoryRouter initialEntries={['/receiving/new']}>
                <Routes><Route path="/receiving/new" element={<>{children}</>} /></Routes>
              </MemoryRouter>
            </DiProvider>
          </QueryClientProvider>
        );
      },
    });

    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260905-001'));
    act(() => result.current.setReceivedOn('2026-09-01'));
    act(() => result.current.setInvoiceNumber('  INV-77  '));
    await act(async () => { await result.current.saveDraft(); });

    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({ invoiceNumber: 'INV-77', receivedOn: '2026-09-01' }),
      'u1',
    );
  });

  it('hydrates invoiceNumber/receivedOn from a resumed draft, and falls back to today when the draft predates the fields', async () => {
    const { result } = renderHook(() => useReceivingEntry(), {
      wrapper: wrap({
        getById: vi.fn(async () => draft({ invoiceNumber: 'INV-9', receivedOn: '2026-08-20' })),
        update: vi.fn(async () => {}),
      } as Partial<Container['receivingRepo']>),
    });

    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    expect(result.current.invoiceNumber).toBe('INV-9');
    expect(result.current.receivedOn).toBe('2026-08-20');
  });

  it('falls back to today when a resumed draft predates receivedOn', async () => {
    const { result } = renderHook(() => useReceivingEntry(), {
      wrapper: wrap({
        getById: vi.fn(async () => draft({ invoiceNumber: null, receivedOn: null })),
        update: vi.fn(async () => {}),
      } as Partial<Container['receivingRepo']>),
    });

    await waitFor(() => expect(result.current.referenceNumber).toBe('RCV-20260829-001'));
    expect(result.current.invoiceNumber).toBe('');
    expect(result.current.receivedOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('setReceivedOn falls back to today\'s shop day when cleared to an empty string (the date input\'s clear button)', async () => {
    const { result } = renderHook(() => useReceivingEntry(), {
      wrapper: wrap({
        getById: vi.fn(async () => draft({ receivedOn: '2026-08-20' })),
        update: vi.fn(async () => {}),
      } as Partial<Container['receivingRepo']>),
    });

    await waitFor(() => expect(result.current.receivedOn).toBe('2026-08-20'));
    act(() => result.current.setReceivedOn(''));
    expect(result.current.receivedOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});

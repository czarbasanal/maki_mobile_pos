import { describe, expect, it, vi } from 'vitest';
import { renderHook, waitFor, act } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useVoidRequests, useResolveVoidRequest } from './useVoidRequests';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { User, VoidRequest } from '@/domain/entities';
import type { ReactNode } from 'react';

const request = (o: Partial<VoidRequest> = {}): VoidRequest => ({
  id: 'r1',
  saleId: 's1',
  saleNumber: 'SALE-001',
  saleGrandTotal: 285,
  requestedBy: 'u-belle',
  requestedByName: 'Belle',
  requestedByRole: 'cashier',
  reason: 'Payment issue',
  status: 'pending',
  read: false,
  createdAt: new Date('2026-08-28T13:00:00Z'),
  resolvedBy: null,
  resolvedByName: null,
  resolvedAt: null,
  rejectionReason: null,
  itemsSummary: null,
  ...o,
});

function wrap(overrides: Partial<Container>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={qc}>
      <DiProvider override={overrides as Container}>{children}</DiProvider>
    </QueryClientProvider>
  );
}

describe('useResolveVoidRequest — the requester cannot decide their own request', () => {
  it('refuses before touching the sale or the request', async () => {
    useAuthStore.setState({
      user: { id: 'u-belle', email: 'b@b.c', displayName: 'Belle', role: 'admin', isActive: true } as User,
    });
    const voidSale = vi.fn(async () => {});
    const resolve = vi.fn(async () => {});
    const { result } = renderHook(() => useResolveVoidRequest(), {
      wrapper: wrap({
        voidRequestRepo: { resolve } as unknown as Container['voidRequestRepo'],
        saleRepo: { voidSale } as unknown as Container['saleRepo'],
        activityLogRepo: { create: vi.fn() } as unknown as Container['activityLogRepo'],
      }),
    });
    await expect(
      result.current.mutateAsync({ request: request({ requestedBy: 'u-belle' }), approve: true }),
    ).rejects.toThrow(/another admin/);
    expect(voidSale).not.toHaveBeenCalled();
    expect(resolve).not.toHaveBeenCalled();
  });
});

describe('useVoidRequests', () => {
  it('counts only unread pending requests toward the badge', async () => {
    const voidRequestRepo = {
      watchPending: (cb: (r: VoidRequest[]) => void) => {
        cb([
          request({ id: 'r1', read: false, status: 'pending' }),
          request({ id: 'r2', read: true, status: 'pending' }),
          // Resolved but never opened: it is history, not a thing to act on.
          request({ id: 'r3', read: false, status: 'approved' }),
        ]);
        return () => {};
      },
    } as unknown as Container['voidRequestRepo'];

    const { result } = renderHook(() => useVoidRequests(), {
      wrapper: wrap({ voidRequestRepo }),
    });

    await waitFor(() => expect(result.current.requests).toHaveLength(3));
    expect(result.current.unreadCount).toBe(1);
    expect(result.current.pending.map((r) => r.id)).toEqual(['r1', 'r2']);
  });
});

describe('useResolveVoidRequest', () => {
  const actor = {
    id: 'u-admin',
    email: 'admin@shop.test',
    displayName: 'Czar',
    role: 'admin',
    isActive: true,
  };

  it('approving voids the sale first, then marks the request approved', async () => {
    const calls: string[] = [];
    const voidSale = vi.fn(async () => { calls.push('voidSale'); });
    const resolve = vi.fn(async () => { calls.push('resolve'); });
    useAuthStore.setState({ user: actor as never });

    const { result } = renderHook(() => useResolveVoidRequest(), {
      wrapper: wrap({
        saleRepo: { voidSale } as unknown as Container['saleRepo'],
        voidRequestRepo: { resolve } as unknown as Container['voidRequestRepo'],
        activityLogRepo: { create: vi.fn() } as unknown as Container['activityLogRepo'],
      }),
    });

    await act(async () => {
      await result.current.mutateAsync({ request: request(), approve: true });
    });

    // Order matters: a request marked approved whose sale never voided would
    // leave the money standing with no way to notice.
    expect(calls).toEqual(['voidSale', 'resolve']);
    expect(voidSale).toHaveBeenCalledWith('s1', 'Payment issue', 'u-admin', 'Czar');
    expect(resolve).toHaveBeenCalledWith(
      expect.objectContaining({ requestId: 'r1', saleId: 's1', status: 'approved' }),
    );
  });

  it('leaves the request pending when the void fails', async () => {
    const voidSale = vi.fn(async () => { throw new Error('This sale is already voided'); });
    const resolve = vi.fn();
    useAuthStore.setState({ user: actor as never });

    const { result } = renderHook(() => useResolveVoidRequest(), {
      wrapper: wrap({
        saleRepo: { voidSale } as unknown as Container['saleRepo'],
        voidRequestRepo: { resolve } as unknown as Container['voidRequestRepo'],
        activityLogRepo: { create: vi.fn() } as unknown as Container['activityLogRepo'],
      }),
    });

    await expect(
      act(async () => {
        await result.current.mutateAsync({ request: request(), approve: true });
      }),
    ).rejects.toThrow('already voided');
    expect(resolve).not.toHaveBeenCalled();
  });

  it('rejecting records the reason and never touches the sale', async () => {
    const voidSale = vi.fn();
    const resolve = vi.fn(async () => {});
    useAuthStore.setState({ user: actor as never });

    const { result } = renderHook(() => useResolveVoidRequest(), {
      wrapper: wrap({
        saleRepo: { voidSale } as unknown as Container['saleRepo'],
        voidRequestRepo: { resolve } as unknown as Container['voidRequestRepo'],
        activityLogRepo: { create: vi.fn() } as unknown as Container['activityLogRepo'],
      }),
    });

    await act(async () => {
      await result.current.mutateAsync({
        request: request(),
        approve: false,
        rejectionReason: 'Sale is correct',
      });
    });

    expect(voidSale).not.toHaveBeenCalled();
    expect(resolve).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'rejected', rejectionReason: 'Sale is correct' }),
    );
  });
});

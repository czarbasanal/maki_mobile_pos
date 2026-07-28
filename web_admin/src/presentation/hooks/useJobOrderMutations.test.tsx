// Review fix: useSaveJobOrder must invalidate the job orders cache — with the app's
// 60s staleTime, JobOrderEditPage would otherwise rehydrate a reopened JO
// from the pre-save cache and a follow-up save would revert the first one.
import { describe, expect, it, vi } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useSaveJobOrder } from './useJobOrderMutations';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { ReactNode } from 'react';

describe('useSaveJobOrder', () => {
  it('invalidates jobOrder queries on success (stale cache would revert saves)', async () => {
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
      status: 'signedIn',
    });
    const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
    qc.setQueryData(['job_orders', 'd1'], { id: 'd1', name: 'JO-072726-001' });
    const update = vi.fn().mockResolvedValue(undefined);
    const jobOrderRepo = { update } as unknown as Container['jobOrderRepo'];
    const activityLogRepo = {
      log: vi.fn().mockResolvedValue(undefined),
    } as unknown as Container['activityLogRepo'];
    const wrapper = ({ children }: { children: ReactNode }) => (
      <DiProvider override={{ jobOrderRepo, activityLogRepo }}>
        <QueryClientProvider client={qc}>{children}</QueryClientProvider>
      </DiProvider>
    );
    const { result } = renderHook(() => useSaveJobOrder(), { wrapper });

    act(() => {
      result.current.mutate({
        jobOrderId: 'd1',
        name: 'JO-072726-001',
        items: [],
        discountType: DiscountType.amount,
        laborLines: [],
        feeLines: [],
        mechanicId: null,
        mechanicName: null,
        notes: 'Fresh note',
      });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(qc.getQueryState(['job_orders', 'd1'])?.isInvalidated).toBe(true);
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });
});

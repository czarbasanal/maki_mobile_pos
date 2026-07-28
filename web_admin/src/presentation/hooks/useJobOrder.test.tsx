import { describe, expect, it, vi } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useJobOrder } from './useJobOrder';
import type { ReactNode } from 'react';

function wrap(jobOrderRepo: Partial<Container['jobOrderRepo']>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: ReactNode }) => (
    <DiProvider override={{ jobOrderRepo: jobOrderRepo as Container['jobOrderRepo'] }}>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </DiProvider>
  );
}

describe('useJobOrder', () => {
  it('fetches one jobOrder by id', async () => {
    const getById = vi.fn().mockResolvedValue({ id: 'd1', name: 'Mr Cruz' });
    const { result } = renderHook(() => useJobOrder('d1'), { wrapper: wrap({ getById }) });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual({ id: 'd1', name: 'Mr Cruz' });
    expect(getById).toHaveBeenCalledWith('d1');
  });
});

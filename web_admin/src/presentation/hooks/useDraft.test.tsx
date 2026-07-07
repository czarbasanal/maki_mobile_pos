import { describe, expect, it, vi } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useDraft } from './useDraft';
import type { ReactNode } from 'react';

function wrap(draftRepo: Partial<Container['draftRepo']>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: ReactNode }) => (
    <DiProvider override={{ draftRepo: draftRepo as Container['draftRepo'] }}>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </DiProvider>
  );
}

describe('useDraft', () => {
  it('fetches one draft by id', async () => {
    const getById = vi.fn().mockResolvedValue({ id: 'd1', name: 'Mr Cruz' });
    const { result } = renderHook(() => useDraft('d1'), { wrapper: wrap({ getById }) });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual({ id: 'd1', name: 'Mr Cruz' });
    expect(getById).toHaveBeenCalledWith('d1');
  });
});

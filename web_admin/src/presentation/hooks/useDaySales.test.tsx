import { describe, expect, it, vi } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useDaySales } from './useDaySales';
import { instantOf, shopWall } from '@/domain/time/shopTime';
import type { ReactNode } from 'react';

describe('useDaySales — shop-day window', () => {
  it("queries the picked CALENDAR date's PHT day, not the device-local day", async () => {
    const list = vi.fn().mockResolvedValue([]);
    const saleRepo = { list } as unknown as Container['saleRepo'];
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    const wrapper = ({ children }: { children: ReactNode }) => (
      <DiProvider override={{ saleRepo }}>
        <QueryClientProvider client={qc}>{children}</QueryClientProvider>
      </DiProvider>
    );
    // The picker hands over a local Date for Sep 1 — the query must window
    // Sep 1 in PHT wherever the browser sits.
    renderHook(() => useDaySales(new Date(2026, 8, 1)), { wrapper });
    await waitFor(() => expect(list).toHaveBeenCalled());
    const { start, end } = list.mock.calls[0][0];
    expect(start.getTime()).toBe(instantOf(shopWall(2026, 9, 1)).getTime());
    expect(end.getTime()).toBe(instantOf(shopWall(2026, 9, 1, 23, 59, 59, 999)).getTime());
  });
});

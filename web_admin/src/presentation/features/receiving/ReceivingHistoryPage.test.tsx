import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { ReceivingHistoryPage } from './ReceivingHistoryPage';

// 3 lines, 12 pieces — totalQuantity is a piece sum, never a line count.
const row = (id: string) => ({
  id,
  referenceNumber: `RCV-2026080${id}`,
  supplierName: 'Acme',
  totalQuantity: 12,
  totalCost: 120,
  status: 'completed',
  createdAt: new Date('2026-08-05'),
  completedAt: new Date('2026-08-05'),
});

vi.mock('@/presentation/hooks/useReceivings', () => ({
  useReceivings: () => ({
    data: [row('1')],
    isLoading: false,
    error: null,
  }),
}));

function renderPage() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter initialEntries={['/receiving/history']}>
        <ReceivingHistoryPage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('ReceivingHistoryPage quantity label', () => {
  it('heads the quantity column "Units", not "Items"', () => {
    renderPage();
    expect(screen.getByRole('columnheader', { name: 'Units' })).toBeInTheDocument();
    expect(screen.queryByRole('columnheader', { name: 'Items' })).toBeNull();
  });
});

import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { ReceivingDashboardPage } from './ReceivingDashboardPage';

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

vi.mock('@/presentation/hooks/useReceivingSummary', () => ({
  useReceivingSummary: () => ({
    isLoading: false,
    completedCount: 1,
    receivedTotal: 120,
    draftCount: 1,
    // Both lists must be non-empty: an empty `recent` gates the completed
    // table behind EmptyState, which would make the header assertion pass
    // vacuously (no header rendered at all).
    drafts: [row('1')],
    recent: [row('2')],
  }),
}));

function renderPage() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter initialEntries={['/receiving']}>
        <ReceivingDashboardPage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('ReceivingDashboardPage quantity label', () => {
  it('labels the drafts row quantity "units", not "items"', () => {
    renderPage();
    expect(screen.getByText('12 units')).toBeInTheDocument();
    expect(screen.queryByText('12 items')).toBeNull();
  });

  it('heads the completed-table quantity column "Units", not "Items"', () => {
    renderPage();
    expect(screen.getByRole('columnheader', { name: 'Units' })).toBeInTheDocument();
    expect(screen.queryByRole('columnheader', { name: 'Items' })).toBeNull();
  });
});

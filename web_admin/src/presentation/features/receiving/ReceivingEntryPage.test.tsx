import { describe, expect, it, vi } from 'vitest';
import { render } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { ReceivingEntryPage } from './ReceivingEntryPage';

// 3 lines, 12 pieces — totalQuantity is a piece sum, never a line count.
const entry = {
  isResuming: false,
  referenceNumber: 'RCV-20260805',
  isLoadingRefs: false,
  suppliers: [],
  supplierId: '',
  setSupplierId: vi.fn(),
  search: '',
  setSearch: vi.fn(),
  matches: [],
  lines: [
    { id: 'i1', productId: 'p1', sku: 'SKU-1', name: 'Brake Pad', quantity: 4, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null, pendingNewProduct: null },
    { id: 'i2', productId: 'p2', sku: 'SKU-2', name: 'Chain', quantity: 5, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null, pendingNewProduct: null },
    { id: 'i3', productId: 'p3', sku: 'SKU-3', name: 'Bolt', quantity: 3, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null, pendingNewProduct: null },
  ],
  addExisting: vi.fn(),
  addNew: vi.fn(),
  removeLine: vi.fn(),
  totals: { quantity: 12, cost: 120 },
  error: null,
  isBusy: false,
  saveDraft: vi.fn(),
  receive: vi.fn(),
};

vi.mock('./useReceivingEntry', () => ({
  useReceivingEntry: () => entry,
}));

vi.mock('@/presentation/hooks/useCategories', () => ({
  useActiveCategories: () => ({ data: [] }),
}));

function renderPage() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter initialEntries={['/receiving/new']}>
        <ReceivingEntryPage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('ReceivingEntryPage quantity label', () => {
  it('labels the footer total quantity "units", not "items"', () => {
    // The footer is unconditional (no loading/empty gate), and the number
    // renders in its own <span> ahead of the word, so the two never share
    // a single text node — assert against the flattened footer text rather
    // than a node-scoped query.
    const { container } = renderPage();
    expect(container.textContent).toContain('12 units');
    expect(container.textContent).not.toContain('12 items');
  });
});

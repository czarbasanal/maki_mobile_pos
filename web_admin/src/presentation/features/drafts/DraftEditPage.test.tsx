import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { DraftEditPage } from './DraftEditPage';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { Draft, Product, Mechanic } from '@/domain/entities';
import type { ReactNode } from 'react';

const draft = (o: Partial<Draft> = {}): Draft => ({
  id: 'd1', name: 'Mr Cruz — Mio', items: [], laborLines: [], mechanicId: null, mechanicName: null,
  discountType: DiscountType.amount, createdBy: 'u1', createdByName: 'C', createdAt: new Date(),
  updatedAt: null, updatedBy: null, isConverted: false, convertedToSaleId: null, convertedAt: null, notes: null, ...o,
});

function harness(draftRepo: Partial<Container['draftRepo']>, node: ReactNode = <DraftEditPage />) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    watchAll: (cb: (products: Product[]) => void) => {
      cb([]);
      return () => {};
    },
  };
  const mechanicRepo: Partial<Container['mechanicRepo']> = {
    watchAll: (cb: (mechanics: Mechanic[]) => void) => {
      cb([]);
      return () => {};
    },
  };
  return render(
    <DiProvider
      override={{
        draftRepo: draftRepo as Container['draftRepo'],
        productRepo: productRepo as Container['productRepo'],
        mechanicRepo: mechanicRepo as Container['mechanicRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/drafts/d1']}>
          <Routes><Route path="/drafts/:id" element={node} /></Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('DraftEditPage', () => {
  it('shows the editor with the draft name once loaded', async () => {
    harness({ getById: vi.fn().mockResolvedValue(draft()) });
    await waitFor(() => expect(screen.getByDisplayValue('Mr Cruz — Mio')).toBeInTheDocument());
  });

  it('blocks editing a converted draft', async () => {
    harness({ getById: vi.fn().mockResolvedValue(draft({ isConverted: true })) });
    await waitFor(() => expect(screen.getByText(/already billed out/i)).toBeInTheDocument());
  });

  it('shows not-found when the draft is missing', async () => {
    harness({ getById: vi.fn().mockResolvedValue(null) });
    await waitFor(() => expect(screen.getByText(/Draft not found/i)).toBeInTheDocument());
  });
});

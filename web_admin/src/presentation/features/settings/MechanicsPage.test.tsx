import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { RoutePaths } from '@/presentation/router/routePaths';
import type { Mechanic } from '@/domain/entities';
import { MechanicsPage } from './MechanicsPage';

function harness(mechanics: Mechanic[]) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const mechanicRepo = {
    watchAll: vi.fn((cb: (m: Mechanic[]) => void) => {
      cb(mechanics);
      return () => {};
    }),
    create: vi.fn(),
    update: vi.fn(),
  } as unknown as Container['mechanicRepo'];
  render(
    <DiProvider override={{ mechanicRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <MechanicsPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('MechanicsPage — back navigation', () => {
  it('renders a back link to Settings', () => {
    harness([]);

    const back = screen.getByRole('link', { name: /settings/i });
    expect(back).toHaveAttribute('href', RoutePaths.settings);
  });
});
